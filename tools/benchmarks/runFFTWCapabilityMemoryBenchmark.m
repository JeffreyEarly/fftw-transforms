function result = runFFTWCapabilityMemoryBenchmark(options)
% Compare fresh-process capability memory before and after JVM-free resolution.
%
% This authoring benchmark archives the released `v1.0.2` source and a clean
% candidate commit, runs each scenario in fresh MATLAB processes, and samples
% the worker externally at phase boundaries.

arguments (Input)
    options.repositoryRoot (1,1) string = fftwBenchmarkPaths().repositoryRoot
    options.baselineRef (1,1) string = "v1.0.2"
    options.candidateRef (1,1) string = "HEAD"
    options.scenarios (1,:) string = ["no-query","java-control","compiler-control","lifecycle"]
    options.nRuns (1,1) double {mustBeInteger,mustBePositive} = 3
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = ""
    options.requireCleanTree (1,1) logical = true
end

repositoryRoot = absolutePath(options.repositoryRoot);
if strlength(options.runId) == 0
    options.runId = string(datetime('now','TimeZone','UTC','Format','yyyyMMdd''T''HHmmssSSS''Z'))+"-"+string(computer('arch'))+"-r"+lower(string(version('-release')));
end
if strlength(options.outputDirectory) == 0
    options.outputDirectory = fullfile(repositoryRoot,"tools","benchmarks","results","issue9",options.runId);
end
outputDirectory = absolutePath(options.outputDirectory);
if ~isfolder(outputDirectory), mkdir(outputDirectory); end

result.schemaVersion = "1.0.0";
result.status = "running";
result.runId = options.runId;
result.generatedAtUTC = utcTimestamp;
result.environment = environmentRecord;
result.configuration.baselineRef = options.baselineRef;
result.configuration.candidateRef = options.candidateRef;
result.configuration.scenarios = options.scenarios;
result.configuration.nFreshProcesses = options.nRuns;
result.configuration.sampler = "external ps RSS plus vmmap mapping/heap evidence at worker handshakes";
result.implementations = repmat(struct,0,1);
result.comparison = struct;
result.attribution = struct;
result.failure = struct('identifier',"",'message',"",'stack',repmat(struct('file',"",'name',"",'line',0),0,1));
result.artifacts.directory = outputDirectory;
result.artifacts.json = fullfile(outputDirectory,"capability-memory.json");
result.artifacts.markdown = fullfile(outputDirectory,"summary.md");

temporaryRoot = string(tempname);
mkdir(temporaryRoot);
temporaryCleanup = onCleanup(@() removeDirectory(temporaryRoot));
state = captureState;
stateCleanup = onCleanup(@() restoreState(state));

try
    if options.requireCleanTree, requireCleanTrackedTree(repositoryRoot); end
    implementations = [struct('id',"v1.0.2",'ref',options.baselineRef) struct('id',"candidate",'ref',options.candidateRef)];
    for iImplementation = 1:numel(implementations)
        snapshotRoot = fullfile(temporaryRoot,implementations(iImplementation).id);
        archiveSnapshot(repositoryRoot,implementations(iImplementation).ref,snapshotRoot);
        implementation.id = implementations(iImplementation).id;
        implementation.ref = implementations(iImplementation).ref;
        implementation.commit = gitOutput(repositoryRoot,"rev-parse "+shellQuote(implementations(iImplementation).ref+"^{commit}"));
        implementation.tree = gitOutput(repositoryRoot,"rev-parse "+shellQuote(implementations(iImplementation).ref+"^{tree}"));
        implementation.sourceHashes = sourceHashes(snapshotRoot);
        implementation.runs = repmat(struct,0,1);
        for scenario = options.scenarios
            for iRun = 1:options.nRuns
                runDirectory = fullfile(temporaryRoot,implementation.id,scenario+"-"+iRun);
                fprintf('Running %s %s fresh process %d of %d.\n',implementation.id,scenario,iRun,options.nRuns);
                run = executeFreshProcess(snapshotRoot,scenario,runDirectory);
                run.index = iRun;
                implementation.runs = appendStruct(implementation.runs,run);
                if run.status ~= "passed"
                    error('FFTWCapabilityMemoryBenchmark:WorkerFailed','%s %s run %d failed: %s',implementation.id,scenario,iRun,jsonencode(run.failure));
                end
            end
        end
        implementation.summary = summarizeRuns(implementation.runs);
        result.implementations = appendStruct(result.implementations,implementation);
    end
    result.comparison = compareImplementations(result.implementations);
    result.attribution = attributeCapabilityMemory(result.implementations);
    result.status = "passed";
catch exception
    result.status = "failed";
    result.failure.identifier = string(exception.identifier);
    result.failure.message = string(exception.message);
    result.failure.stack = exception.stack;
end

result.completedAtUTC = utcTimestamp;
writeArtifacts(result);
clear stateCleanup temporaryCleanup
if result.status ~= "passed"
    error('FFTWCapabilityMemoryBenchmark:Failed','%s',result.failure.message);
end
end

function run = executeFreshProcess(sourceRoot,scenario,runDirectory)
mkdir(runDirectory);
benchmarkDirectory = string(fileparts(mfilename('fullpath')));
expression = "addpath("+matlabString(benchmarkDirectory)+"); runFFTWCapabilityMemoryWorker("+matlabString(sourceRoot)+","+matlabString(scenario)+","+matlabString(runDirectory)+")";
logPath = fullfile(runDirectory,"matlab.log");
command = shellQuote(fullfile(matlabroot,"bin","matlab"))+" -batch "+shellQuote(expression)+" > "+shellQuote(logPath)+" 2>&1 & echo $!";
[status,output] = system(command);
if status ~= 0, error('FFTWCapabilityMemoryBenchmark:LaunchFailed','Unable to launch MATLAB: %s',output); end
launcherPid = str2double(strip(string(output)));
if ~isfinite(launcherPid), error('FFTWCapabilityMemoryBenchmark:LaunchFailed','Unable to parse the MATLAB launcher PID from %s.',output); end

run.scenario = scenario;
run.launcherProcessId = launcherPid;
run.status = "running";
run.phases = repmat(struct,0,1);
run.failure = struct('identifier',"",'message',"");
seen = strings(1,0);
resultPath = fullfile(runDirectory,"worker-result.json");
deadline = tic;
while toc(deadline) < 900
    readyFiles = dir(fullfile(runDirectory,"*.ready"));
    [~,order] = sort(string({readyFiles.name}));
    readyFiles = readyFiles(order);
    for iFile = 1:numel(readyFiles)
        readyName = string(readyFiles(iFile).name);
        if any(seen == readyName), continue, end
        sample = sampleProcessTree(launcherPid);
        tokens = regexp(readyName,'^\d+-(.*)\.ready$','tokens','once');
        sample.name = string(tokens{1});
        run.phases = appendStruct(run.phases,sample);
        fprintf('  sampled %s at %.3f MiB RSS.\n',sample.name,sample.workerRSSBytes/2^20);
        acknowledgement = replace(fullfile(runDirectory,readyName),".ready",".ack");
        fileId = fopen(acknowledgement,'w');
        fclose(fileId);
        seen(end+1) = readyName; %#ok<AGROW>
    end
    if isfile(resultPath)
        pause(0.1);
        worker = jsondecode(fileread(resultPath));
        run.status = string(worker.status);
        if isfield(worker,'failure'), run.failure = worker.failure; end
        if isfield(worker,'capabilities'), run.capabilities = worker.capabilities; end
        run.workerProcessId = worker.processId;
        break
    end
    [aliveStatus,~] = system("/bin/kill -0 "+launcherPid+" 2>/dev/null");
    if aliveStatus ~= 0
        run.status = "failed";
        run.failure.identifier = "FFTWCapabilityMemoryBenchmark:WorkerExited";
        if isfile(logPath)
            run.failure.message = "The fresh MATLAB worker exited before writing a result: "+string(fileread(logPath));
        else
            run.failure.message = "The fresh MATLAB worker exited before writing a result.";
        end
        break
    end
    pause(0.05);
end
if run.status == "running"
    run.status = "failed";
    run.failure.identifier = "FFTWCapabilityMemoryBenchmark:WorkerTimeout";
    run.failure.message = "The fresh MATLAB worker did not finish within 900 seconds.";
end
run.log = string(fileread(logPath));
run.mexHashes = mexHashes(sourceRoot);
end

function sample = sampleProcessTree(launcherPid)
[status,output] = system("/bin/ps -axo pid=,ppid=,rss=,comm=");
if status ~= 0, error('FFTWCapabilityMemoryBenchmark:ProcessSampleFailed','ps failed: %s',output); end
lines = splitlines(string(output));
records = repmat(struct('pid',0,'ppid',0,'rssKiB',0,'command',""),0,1);
for line = lines.'
    token = regexp(line,'^\s*(\d+)\s+(\d+)\s+(\d+)\s+(.+)$','tokens','once');
    if isempty(token), continue, end
    record.pid = str2double(token{1});
    record.ppid = str2double(token{2});
    record.rssKiB = str2double(token{3});
    record.command = string(token{4});
    records(end+1,1) = record; %#ok<AGROW>
end
selected = records([records.pid] == launcherPid);
frontier = launcherPid;
while ~isempty(frontier)
    children = records(ismember([records.ppid],frontier));
    newChildren = children(~ismember([children.pid],[selected.pid]));
    selected = [selected; newChildren]; %#ok<AGROW>
    frontier = [newChildren.pid];
end
if isempty(selected), error('FFTWCapabilityMemoryBenchmark:ProcessExited','The MATLAB process exited before it could be sampled.'); end
[~,workerIndex] = max([selected.rssKiB]);
worker = selected(workerIndex);
sample.workerProcessId = worker.pid;
sample.workerRSSBytes = worker.rssKiB*1024;
sample.processTreeRSSBytes = sum([selected.rssKiB])*1024;
sample.processTree = selected;
[vmmapStatus,vmmapOutput] = system("/usr/bin/vmmap "+worker.pid);
sample.vmmapStatus = vmmapStatus;
if vmmapStatus == 0
    vmmapLines = splitlines(string(vmmapOutput));
    javaMask = contains(lower(vmmapLines),["java","libjvm","libjli","jimage"]);
    heapMask = contains(lower(vmmapLines),["java heap","gc heap"]);
    sample.javaRuntimeMappingsPresent = any(javaMask);
    sample.javaHeapRegionsPresent = any(heapMask);
    sample.javaEvidence = vmmapLines(javaMask | heapMask);
else
    sample.javaRuntimeMappingsPresent = false;
    sample.javaHeapRegionsPresent = false;
    sample.javaEvidence = strings(0,1);
end
end

function summary = summarizeRuns(runs)
scenarios = unique(string({runs.scenario}),'stable');
summary = repmat(struct,0,1);
for scenario = scenarios
    scenarioRuns = runs(string({runs.scenario}) == scenario);
    phaseNames = strings(0,1);
    for iRun = 1:numel(scenarioRuns)
        phaseNames = [phaseNames; string({scenarioRuns(iRun).phases.name}).']; %#ok<AGROW>
    end
    phaseNames = unique(phaseNames,'stable');
    for phaseName = phaseNames.'
        samples = [];
        javaMappings = false(1,0);
        javaHeaps = false(1,0);
        for run = scenarioRuns.'
            phase = run.phases(string({run.phases.name}) == phaseName);
            samples(end+1) = phase.workerRSSBytes; %#ok<AGROW>
            javaMappings(end+1) = phase.javaRuntimeMappingsPresent; %#ok<AGROW>
            javaHeaps(end+1) = phase.javaHeapRegionsPresent; %#ok<AGROW>
        end
        item.scenario = scenario;
        item.phase = phaseName;
        item.rssSamplesBytes = samples;
        item.rssMedianBytes = median(samples);
        item.rssRangeBytes = [min(samples) max(samples)];
        item.javaRuntimeMappingsPresent = javaMappings;
        item.javaHeapRegionsPresent = javaHeaps;
        summary = appendStruct(summary,item);
    end
end
end

function comparison = compareImplementations(implementations)
baseline = implementations(1).summary;
candidate = implementations(2).summary;
comparison = repmat(struct,0,1);
for iCandidate = 1:numel(candidate)
    match = find([baseline.scenario] == candidate(iCandidate).scenario & [baseline.phase] == candidate(iCandidate).phase,1);
    if isempty(match), continue, end
    item.scenario = candidate(iCandidate).scenario;
    item.phase = candidate(iCandidate).phase;
    item.baselineRSSMedianBytes = baseline(match).rssMedianBytes;
    item.candidateRSSMedianBytes = candidate(iCandidate).rssMedianBytes;
    item.candidateMinusBaselineBytes = item.candidateRSSMedianBytes-item.baselineRSSMedianBytes;
    comparison = appendStruct(comparison,item);
end
end

function writeArtifacts(result)
if ~isfolder(result.artifacts.directory), mkdir(result.artifacts.directory); end
fileId = fopen(result.artifacts.json,'w');
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId,jsonencode(result,PrettyPrint=true),'char');
clear cleanup

lines = ["# FFTW capability memory benchmark" "" "| Field | Value |" "|---|---:|" ...
    "| Status | "+result.status+" |" ...
    "| MATLAB | "+result.environment.matlabRelease+" |" ...
    "| Architecture | "+result.environment.architecture+" |" "" ...
    "## RSS comparison" "" ...
    "| Scenario | Phase | v1.0.2 RSS (MiB) | Candidate RSS (MiB) | Candidate - v1.0.2 (MiB) |" ...
    "|---|---|---:|---:|---:|"];
if result.status == "passed"
    for item = result.comparison.'
        lines(end+1) = sprintf('| %s | %s | %.3f | %.3f | %+.3f |',item.scenario,item.phase,item.baselineRSSMedianBytes/2^20,item.candidateRSSMedianBytes/2^20,item.candidateMinusBaselineBytes/2^20); %#ok<AGROW>
    end
end
lines(end+1:end+4) = ["" "## Java-state evidence" "" "See `capability-memory.json` for per-phase `vmmap` evidence, process trees, and raw samples."];
if result.status == "passed" && result.attribution.wasEvaluated
    lines(end+1:end+8) = ["" "## Capability-query attribution" "" ...
        "| Measurement | RSS (MiB) |" "|---|---:|" ...
        sprintf('| v1.0.2 capability increment | %.3f |',result.attribution.baselineCapabilityIncrementBytes/2^20) ...
        sprintf('| Candidate capability increment | %.3f |',result.attribution.candidateCapabilityIncrementBytes/2^20) ...
        sprintf('| JVM-free reduction | %.3f |',result.attribution.capabilityReductionBytes/2^20)];
end
fileId = fopen(result.artifacts.markdown,'w');
cleanup = onCleanup(@() fclose(fileId));
fprintf(fileId,'%s\n',lines);
clear cleanup
end

function archiveSnapshot(repositoryRoot,ref,destination)
mkdir(destination);
command = "git -C "+shellQuote(repositoryRoot)+" archive --format=tar "+shellQuote(ref)+" | /usr/bin/tar -xf - -C "+shellQuote(destination);
[status,output] = system(command);
if status ~= 0, error('FFTWCapabilityMemoryBenchmark:ArchiveFailed','Unable to archive %s: %s',ref,output); end
end

function requireCleanTrackedTree(repositoryRoot)
[status,output] = system("git -C "+shellQuote(repositoryRoot)+" status --porcelain --untracked-files=no");
if status ~= 0 || strlength(strip(string(output))) > 0
    error('FFTWCapabilityMemoryBenchmark:DirtyTree','The tracked candidate tree must be clean before benchmarking.');
end
end

function value = gitOutput(repositoryRoot,arguments)
[status,output] = system("git -C "+shellQuote(repositoryRoot)+" "+arguments);
if status ~= 0, error('FFTWCapabilityMemoryBenchmark:GitFailed','git %s failed: %s',arguments,output); end
value = strip(string(output));
end

function hashes = sourceHashes(sourceRoot)
paths = ["FFTWBackend.m","RealToComplexTransform.m","RealToRealTransform.m","fftw_r2c.cpp","fftw_r2r.cpp","fftw_backend_support.hpp"];
hashes = repmat(struct('path',"",'sha256',""),numel(paths),1);
for iPath = 1:numel(paths)
    hashes(iPath).path = paths(iPath);
    hashes(iPath).sha256 = sha256(fullfile(sourceRoot,paths(iPath)));
end
end

function hashes = mexHashes(sourceRoot)
files = dir(fullfile(sourceRoot,"*."+mexext));
hashes = repmat(struct('path',"",'sha256',""),numel(files),1);
for iFile = 1:numel(files)
    hashes(iFile).path = string(files(iFile).name);
    hashes(iFile).sha256 = sha256(fullfile(sourceRoot,files(iFile).name));
end
end

function value = sha256(path)
[status,output] = system("/usr/bin/shasum -a 256 "+shellQuote(path));
if status ~= 0, error('FFTWCapabilityMemoryBenchmark:HashFailed','Unable to hash %s.',path); end
value = extractBefore(strip(string(output)),65);
end

function environment = environmentRecord()
environment.matlabVersion = string(version);
environment.matlabRelease = string(version('-release'));
environment.architecture = string(computer('arch'));
environment.operatingSystem = string(system_dependent('getos'));
[~,processor] = system('/usr/sbin/sysctl -n machdep.cpu.brand_string');
environment.processor = strip(string(processor));
environment.sampler.ps = "/bin/ps RSS in KiB";
environment.sampler.vmmap = "/usr/bin/vmmap";
end

function state = captureState()
state.directory = string(pwd);
state.path = path;
state.random = rng;
end

function restoreState(state)
path(state.path);
cd(state.directory);
rng(state.random);
end

function path = absolutePath(path)
path = string(path);
if ~startsWith(path,filesep), path = fullfile(string(pwd),path); end
end

function value = matlabString(value)
value = "'"+replace(string(value),"'","''")+"'";
end

function value = shellQuote(value)
value = "'"+replace(string(value),"'","'""'""'")+"'";
end

function value = utcTimestamp()
value = string(datetime('now','TimeZone','UTC','Format','yyyy-MM-dd''T''HH:mm:ss.SSS''Z'));
end

function removeDirectory(path)
if isfolder(path), rmdir(path,'s'); end
end

function attribution = attributeCapabilityMemory(implementations)
baseline = implementations(1).summary;
candidate = implementations(2).summary;
required = ["no-query","java-control","compiler-control","lifecycle"];
attribution.wasEvaluated = all(ismember(required,unique([candidate.scenario])));
if ~attribution.wasEvaluated, return, end
attribution.baselineCapabilityIncrementBytes = phaseMedian(baseline,"lifecycle","capability-query")-phaseMedian(baseline,"lifecycle","startup");
attribution.candidateCapabilityIncrementBytes = phaseMedian(candidate,"lifecycle","capability-query")-phaseMedian(candidate,"lifecycle","startup");
attribution.capabilityReductionBytes = attribution.baselineCapabilityIncrementBytes-attribution.candidateCapabilityIncrementBytes;
attribution.baselineJavaControlIncrementBytes = phaseMedian(baseline,"java-control","java-positive-control")-phaseMedian(baseline,"java-control","startup");
attribution.candidateJavaControlIncrementBytes = phaseMedian(candidate,"java-control","java-positive-control")-phaseMedian(candidate,"java-control","startup");
attribution.baselineCompilerControlIncrementBytes = phaseMedian(baseline,"compiler-control","compiler-discovery-control")-phaseMedian(baseline,"compiler-control","startup");
attribution.candidateCompilerControlIncrementBytes = phaseMedian(candidate,"compiler-control","compiler-discovery-control")-phaseMedian(candidate,"compiler-control","startup");
attribution.remainingCandidateIncrementBeyondCompilerBytes = attribution.candidateCapabilityIncrementBytes-attribution.candidateCompilerControlIncrementBytes;
attribution.candidateJavaStateMatchesNoQuery = phaseJavaState(candidate,"lifecycle","capability-query") == phaseJavaState(candidate,"no-query","no-query-control");
end

function value = phaseMedian(summary,scenario,phase)
index = find([summary.scenario] == scenario & [summary.phase] == phase,1);
if isempty(index), error('FFTWCapabilityMemoryBenchmark:MissingPhase','Missing %s/%s.',scenario,phase); end
value = summary(index).rssMedianBytes;
end

function value = phaseJavaState(summary,scenario,phase)
index = find([summary.scenario] == scenario & [summary.phase] == phase,1);
if isempty(index), error('FFTWCapabilityMemoryBenchmark:MissingPhase','Missing %s/%s.',scenario,phase); end
value = string(all(summary(index).javaRuntimeMappingsPresent))+"/"+string(all(summary(index).javaHeapRegionsPresent));
end

function array = appendStruct(array,item)
if isempty(array)
    array = item;
else
    array(end+1,1) = item;
end
end
