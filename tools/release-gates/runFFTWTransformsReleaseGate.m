function result = runFFTWTransformsReleaseGate(options)
%RUNFFTWTRANSFORMSRELEASEGATE Validate authoring and exported package trees.
%   RESULT = RUNFFTWTRANSFORMSRELEASEGATE() runs the canonical Apple release
%   gate. Set requireCanonicalPlatform=false for the portable Linux gate.

arguments
    options.repositoryRoot (1,1) string = ""
    options.oceanKitRoot (1,1) string = ""
    options.outputDirectory (1,1) string = ""
    options.runId (1,1) string = ""
    options.candidateVersion (1,1) string = "1.0.0"
    options.requireCanonicalPlatform (1,1) logical = true
    options.candidateSourceCommit (1,1) string = ""
end

toolDirectory = string(fileparts(mfilename('fullpath')));
if strlength(options.repositoryRoot) == 0
    options.repositoryRoot = canonicalPath(fullfile(toolDirectory,"..",".."));
else
    options.repositoryRoot = canonicalPath(options.repositoryRoot);
end
if strlength(options.outputDirectory) == 0
    options.outputDirectory = fullfile(toolDirectory,"results");
end
if strlength(options.runId) == 0
    options.runId = string(datetime('now',TimeZone='UTC',Format="yyyyMMdd'T'HHmmssSSS'Z'")) + "-" + string(computer('arch')) + "-r" + lower(string(version('-release')));
end

runDirectory = fullfile(options.outputDirectory,options.runId);
if isfolder(runDirectory) || isfile(runDirectory)
    error('FFTWTransforms:ReleaseGateOutputExists','Release-gate output already exists at %s.',runDirectory);
end
mkdir(runDirectory);

previousDirectory = string(pwd);
previousPath = string(path);
previousPlanner = string(fftw('planner'));
previousWisdom = fftw('dwisdom');
previousThreads = maxNumCompThreads;
previousRandom = rng;
temporaryRoot = string(tempname);
mkdir(temporaryRoot);
stateCleanup = onCleanup(@() restoreState(previousDirectory,previousPath,previousPlanner,previousWisdom,previousThreads,previousRandom,temporaryRoot));

result = initializeResult(options,runDirectory);
activeStage = "preflight";
try
    assertCanonicalPlatform(options.requireCanonicalPlatform);
    [result.source.commit,result.source.tree] = sourceIdentity(options.repositoryRoot);
    if strlength(options.candidateSourceCommit) == 0
        options.candidateSourceCommit = result.source.commit;
    end
    result.candidateSourceCommit = options.candidateSourceCommit;
    requireEqual(result.source.commit,options.candidateSourceCommit,'FFTWTransforms:ReleaseGateSourceMismatch','The checked-out source is not candidateSourceCommit.');
    requireCleanTrackedTree(options.repositoryRoot);

    activeStage = "authoring-tests";
    addpath(options.repositoryRoot);
    addpath(fullfile(options.repositoryRoot,"UnitTests"));
    addpath(fullfile(options.repositoryRoot,"tools","benchmarks"));
    addpath(fullfile(options.repositoryRoot,"tools","benchmarks","UnitTests"));
    result.package.authoring = packageIdentity(options.repositoryRoot);
    requireEqual(result.package.authoring.version,"0.1.0",'FFTWTransforms:ReleaseGateAuthoringVersion','The tracked authoring version must remain 0.1.0.');
    authoringFiles = applicableAuthoringTests(options.repositoryRoot);
    cd(options.repositoryRoot);
    result.tests.authoring = runTestFiles(authoringFiles);
    cd(temporaryRoot);
    result.tests.unrelatedDirectory = runTestFiles(fullfile(options.repositoryRoot,"UnitTests","TestPackageScaffold.m"));

    activeStage = "source-archive";
    archiveRoot = fullfile(temporaryRoot,"source");
    mkdir(archiveRoot);
    archivePath = fullfile(temporaryRoot,"source.tar");
    command = sprintf('git -C "%s" archive --format=tar -o "%s" %s',options.repositoryRoot,archivePath,options.candidateSourceCommit);
    runCommand(command,'FFTWTransforms:ReleaseGateArchiveFailed');
    untar(archivePath,archiveRoot);
    archivedPackage = packageIdentity(archiveRoot);
    requireEqual(archivedPackage.version,"0.1.0",'FFTWTransforms:ReleaseGateArchiveVersion','The archived source did not retain version 0.1.0.');

    activeStage = "export";
    oceanKitRoot = resolveOceanKitRoot(options.repositoryRoot,options.oceanKitRoot);
    result.exporter.repository = "JeffreyEarly/OceanKit";
    [result.exporter.commit,result.exporter.tree] = sourceIdentity(oceanKitRoot);
    exporterPath = fullfile(oceanKitRoot,"tools","ci_release.m");
    result.exporter.path = "tools/ci_release.m";
    result.exporter.sha256 = fileSHA256(exporterPath);
    addpath(fullfile(oceanKitRoot,"tools"),'-begin');
    addpath(fullfile(archiveRoot,"tools"),'-begin');
    ci_release(rootDir=archiveRoot,bumpType="major",notes="FFTWTransforms 1.0.0 release candidate",shouldBuildWebsiteDocumentation=true,shouldPackageForDistribution=true);
    exportRoot = fullfile(archiveRoot,"dist","FFTWTransforms-" + options.candidateVersion);
    if ~isfolder(exportRoot)
        error('FFTWTransforms:ReleaseGateExportMissing','OceanKit did not create %s.',exportRoot);
    end
    result.package.exported = packageIdentity(exportRoot);
    requireEqual(result.package.exported.version,options.candidateVersion,'FFTWTransforms:ReleaseGateCandidateVersion','The exported package has the wrong version.');
    requireEqual(result.package.exported.id,result.package.authoring.id,'FFTWTransforms:ReleaseGatePackageIdentity','The package UUID changed during export.');
    result.export.prebuildFiles = fileManifest(exportRoot);
    result.export.prebuildDigest = manifestDigest(result.export.prebuildFiles);
    result.export.hygiene = verifyExportHygiene(exportRoot,result.export.prebuildFiles);
    if ~result.export.hygiene.passed
        error('FFTWTransforms:ReleaseGateExportHygiene','The pre-build export contains authoring or generated files.');
    end
    requireEqual(packageIdentity(options.repositoryRoot).version,"0.1.0",'FFTWTransforms:ReleaseGateManifestChanged','The real authoring manifest was modified.');

    activeStage = "clean-export-tests";
    clear('fftw_r2c','fftw_r2r');
    restoredefaultpath;
    addpath(exportRoot);
    addpath(fullfile(exportRoot,"UnitTests"));
    cd(temporaryRoot);
    resolvedBackend = string(which('FFTWBackend'));
    if ~startsWith(canonicalPath(resolvedBackend),canonicalPath(exportRoot))
        error('FFTWTransforms:ReleaseGatePathLeak','FFTWBackend did not resolve from the exported snapshot.');
    end
    if isCanonicalPlatform
        buildResult = FFTWBackend.build();
        if ~buildResult.isComplete
            error('FFTWTransforms:ReleaseGateBuildFailed','Exported MEX build failed: %s',buildResult.build.reason.message);
        end
        result.tests.exported = runTestFiles(exportedProductionTests(exportRoot));
        result.capabilities = FFTWBackend.capabilities();
        result.numerics = numericalSummary(result.capabilities);
        result.validation = canonicalValidation(result.capabilities,result.tests.exported,exportRoot);
    else
        beforeMex = generatedMexFiles(exportRoot);
        result.tests.exported = runTestFiles([fullfile(exportRoot,"UnitTests","TestPackageScaffold.m"),fullfile(exportRoot,"UnitTests","TestFFTWBackendPortable.m")]);
        result.capabilities = FFTWBackend.capabilities();
        buildResult = FFTWBackend.build();
        afterMex = generatedMexFiles(exportRoot);
        result.validation = portableValidation(result.capabilities,buildResult,beforeMex,afterMex);
        result.numerics = struct('maximumRelativeError',NaN);
    end
    result.export.postbuildMexFiles = generatedMexFiles(exportRoot);

    activeStage = "history";
    historyPath = fullfile(options.repositoryRoot,"tools","benchmarks","benchmark-history.json");
    result.benchmarkHistory.path = "tools/benchmarks/benchmark-history.json";
    result.benchmarkHistory.sha256 = fileSHA256(historyPath);
    result.benchmarkHistory.record = jsondecode(fileread(historyPath));
    result.runtimeHashes = runtimeHashes(options.repositoryRoot);
    result.status = "passed";
    result.completedAtUTC = utcTimestamp;
    writeArtifacts(result,runDirectory);
catch exception
    result.status = "failed";
    result.completedAtUTC = utcTimestamp;
    result.failure.stage = activeStage;
    result.failure.identifier = string(exception.identifier);
    result.failure.message = string(exception.message);
    result.failure.stack = stackRecord(exception.stack);
    try
        writeArtifacts(result,runDirectory);
    catch artifactException
        warning('FFTWTransforms:ReleaseGateArtifactWriteFailed','Unable to write partial release-gate artifacts: %s',artifactException.message);
    end
    rethrow(exception);
end
clear stateCleanup
end

function result = initializeResult(options,runDirectory)
result.schemaVersion = "1.0.0";
result.status = "running";
result.runId = options.runId;
result.generatedAtUTC = utcTimestamp;
result.completedAtUTC = "";
result.candidateVersion = options.candidateVersion;
result.candidateSourceCommit = options.candidateSourceCommit;
result.environment = collectEnvironment;
result.environment.canonicalPlatformRequired = options.requireCanonicalPlatform;
result.environment.canonicalPlatform = isCanonicalPlatform;
result.source = struct;
result.package = struct;
result.exporter = struct;
result.export = struct;
result.tests = struct;
result.capabilities = struct;
result.numerics = struct;
result.validation = struct;
result.benchmarkHistory = struct;
result.runtimeHashes = repmat(struct('path',"",'sha256',""),0,1);
result.failure = [];
result.artifacts.directory = runDirectory;
result.artifacts.json = "release-gate.json";
result.artifacts.markdown = "summary.md";
end

function environment = collectEnvironment()
environment.matlabVersion = string(version);
environment.matlabRelease = string(version('-release'));
environment.architecture = string(computer('arch'));
environment.operatingSystem = string(system_dependent('getos'));
environment.processor = "unknown";
environment.machineModel = "unknown";
environment.physicalMemoryBytes = NaN;
[status,hardwareText] = system('system_profiler SPHardwareDataType -json');
if status == 0
    hardware = jsondecode(hardwareText).SPHardwareDataType(1);
    if isfield(hardware,'chip_type')
        environment.processor = string(hardware.chip_type);
    end
    if isfield(hardware,'machine_model')
        environment.machineModel = string(hardware.machine_model);
    end
end
[status,memoryText] = system('sysctl -n hw.memsize');
if status == 0
    environment.physicalMemoryBytes = str2double(strtrim(memoryText));
end
environment.mexCompiler = "unavailable";
environment.mexCompilerVersion = "";
try
    compiler = mex.getCompilerConfigurations('C++','Selected');
    if ~isempty(compiler)
        environment.mexCompiler = string(compiler(1).Name);
        environment.mexCompilerVersion = string(compiler(1).Version);
    end
catch
end
end

function files = applicableAuthoringTests(repositoryRoot)
if isCanonicalPlatform
    files = [
        fullfile(repositoryRoot,"UnitTests","TestPackageScaffold.m")
        fullfile(repositoryRoot,"UnitTests","TestRealToComplexTransform.m")
        fullfile(repositoryRoot,"UnitTests","TestRealToRealTransform.m")
        fullfile(repositoryRoot,"UnitTests","TestFFTWBackend.m")
        fullfile(repositoryRoot,"tools","benchmarks","UnitTests","TestFFTWBenchmarkHistory.m")
        fullfile(repositoryRoot,"tools","benchmarks","UnitTests","TestFFTWFeasibilityBaseline.m")
        fullfile(repositoryRoot,"tools","benchmarks","UnitTests","TestFFTWEngineLayoutBenchmark.m")
        fullfile(repositoryRoot,"tools","benchmarks","UnitTests","TestFFTWMexOwnershipBenchmark.m")
        fullfile(repositoryRoot,"tools","benchmarks","UnitTests","TestFFTWR2RBenchmark.m")
        ];
else
    files = [
        fullfile(repositoryRoot,"UnitTests","TestPackageScaffold.m")
        fullfile(repositoryRoot,"UnitTests","TestFFTWBackendPortable.m")
        fullfile(repositoryRoot,"tools","benchmarks","UnitTests","TestFFTWBenchmarkHistory.m")
        ];
end
end

function files = exportedProductionTests(exportRoot)
files = [
    fullfile(exportRoot,"UnitTests","TestPackageScaffold.m")
    fullfile(exportRoot,"UnitTests","TestRealToComplexTransform.m")
    fullfile(exportRoot,"UnitTests","TestRealToRealTransform.m")
    fullfile(exportRoot,"UnitTests","TestFFTWBackend.m")
    ];
end

function summary = runTestFiles(files)
files = string(files);
results = runtests(cellstr(files));
summary.count = numel(results);
summary.passed = sum([results.Passed]);
summary.failed = sum([results.Failed]);
summary.incomplete = sum([results.Incomplete]);
summary.durationSeconds = sum([results.Duration]);
summary.details = repmat(struct('name',"",'passed',false,'failed',false,'incomplete',false,'durationSeconds',0),numel(results),1);
for iResult = 1:numel(results)
    summary.details(iResult).name = string(results(iResult).Name);
    summary.details(iResult).passed = results(iResult).Passed;
    summary.details(iResult).failed = results(iResult).Failed;
    summary.details(iResult).incomplete = results(iResult).Incomplete;
    summary.details(iResult).durationSeconds = results(iResult).Duration;
end
if summary.failed > 0
    error('FFTWTransforms:ReleaseGateTestsFailed','%d tests failed.',summary.failed);
end
end

function identity = packageIdentity(root)
package = matlab.mpm.Package(root);
identity.name = string(package.Name);
identity.displayName = string(package.DisplayName);
identity.version = string(package.Version);
identity.id = string(package.ID);
identity.releaseCompatibility = string(package.ReleaseCompatibility);
dependencies = package.Dependencies;
identity.dependencies = strings(1,numel(dependencies));
for iDependency = 1:numel(dependencies)
    identity.dependencies(iDependency) = string(dependencies(iDependency).Name);
end
folders = package.Folders;
identity.folders = strings(1,numel(folders));
for iFolder = 1:numel(folders)
    identity.folders(iFolder) = string(folders(iFolder).Path);
end
if identity.name ~= "FFTWTransforms" || identity.id ~= "c9f6616c-d26a-4fdc-8426-91ca8ffd751b" || identity.releaseCompatibility ~= ">=R2024b" || ~isempty(identity.dependencies)
    error('FFTWTransforms:ReleaseGatePackageIdentity','Unexpected FFTWTransforms package identity.');
end
end

function manifest = fileManifest(root)
entries = dir(fullfile(root,"**","*"));
entries = entries(~[entries.isdir]);
relative = strings(numel(entries),1);
for iEntry = 1:numel(entries)
    relative(iEntry) = erase(string(fullfile(entries(iEntry).folder,entries(iEntry).name)),string(root)+filesep);
end
[relative,order] = sort(replace(relative,"\","/"));
entries = entries(order);
manifest = repmat(struct('path',"",'bytes',0,'sha256',""),numel(entries),1);
for iEntry = 1:numel(entries)
    manifest(iEntry).path = relative(iEntry);
    manifest(iEntry).bytes = entries(iEntry).bytes;
    manifest(iEntry).sha256 = fileSHA256(fullfile(entries(iEntry).folder,entries(iEntry).name));
end
end

function digest = manifestDigest(manifest)
lines = strings(numel(manifest),1);
for iFile = 1:numel(manifest)
    lines(iFile) = manifest(iFile).path + ":" + manifest(iFile).sha256;
end
digest = textSHA256(join(lines,newline));
end

function hygiene = verifyExportHygiene(exportRoot,manifest)
paths = string({manifest.path});
folderPrefixes = ["tools/","docs/","Documentation/",".github/","dist/","build/",".fftw-cache/","native-fftw-cache/"];
forbiddenFolder = false(size(paths));
for prefix = folderPrefixes
    forbiddenFolder = forbiddenFolder | startsWith(paths,prefix);
end
forbiddenExtension = endsWith(paths,[".mexa64",".mexmaci64",".mexmaca64",".mexw64",".o",".obj",".a",".dylib",".so",".dll",".tar",".tar.gz",".zip"]);
hygiene.forbiddenFiles = paths(forbiddenFolder | forbiddenExtension);
hygiene.passed = isempty(hygiene.forbiddenFiles) && isfile(fullfile(exportRoot,"FFTWBackend.m"));
end

function summary = numericalSummary(capabilities)
names = ["r2c","c2r","dct1","dst1"];
summary.features = repmat(struct('id',"",'maximumRelativeError',NaN,'passed',false),numel(names),1);
for iName = 1:numel(names)
    feature = capabilities.features.(names(iName));
    summary.features(iName).id = names(iName);
    summary.features(iName).maximumRelativeError = feature.maximumRelativeError;
    summary.features(iName).passed = feature.maximumRelativeError <= 1e-12;
end
summary.maximumRelativeError = max([summary.features.maximumRelativeError]);
end

function validation = canonicalValidation(capabilities,tests,exportRoot)
validation.providerIsBundled = capabilities.provider.id == "matlab-bundled";
validation.libraryVersionPassed = capabilities.library.version == "fftw-3.3.8";
validation.libraryIdentityPassed = capabilities.library.identityValidated && capabilities.library.resolvedPath == capabilities.library.expectedPath;
validation.numericalPassed = all([capabilities.features.r2c.maximumRelativeError capabilities.features.c2r.maximumRelativeError capabilities.features.dct1.maximumRelativeError capabilities.features.dst1.maximumRelativeError] <= 1e-12);
names = string({tests.details.name});
passed = [tests.details.passed];
validation.ownershipAndPointerPassed = any(passed & contains(names,"Ownership"));
validation.alignmentPassed = any(passed & contains(names,"Alignment"));
validation.rollbackPassed = any(passed & contains(names,"TransactionalRollback"));
validation.cleanupPassed = any(passed & (contains(names,"Cleanup") | contains(names,"Lifetime")));
validation.moduleLocksBalanced = validation.cleanupPassed;
validation.modulesBesideExport = startsWith(canonicalPath(capabilities.modules.r2c.path),canonicalPath(exportRoot)) && startsWith(canonicalPath(capabilities.modules.r2r.path),canonicalPath(exportRoot));
validation.passed = all(structfun(@(value) islogical(value) && isscalar(value) && value,validation));
end

function validation = portableValidation(capabilities,buildResult,beforeMex,afterMex)
validation.structuredUnavailable = capabilities.status == "unavailable" && ~capabilities.isAvailable;
validation.buildAttempted = buildResult.build.attempted;
validation.noCompilation = ~buildResult.build.succeeded && ~buildResult.build.installed;
validation.noMexCreated = isequal(beforeMex,afterMex) && isempty(afterMex);
validation.passed = validation.structuredUnavailable && validation.buildAttempted && validation.noCompilation && validation.noMexCreated;
if ~validation.passed
    error('FFTWTransforms:ReleaseGatePortableValidation','Portable structured-unavailability checks failed.');
end
end

function hashes = runtimeHashes(root)
names = ["FFTWBackend.m","RealToComplexTransform.m","RealToRealTransform.m","RealToRealTransformMexFFTW.m","fftw_r2c.cpp","fftw_r2r.cpp","fftw_backend_support.hpp","fftw3.h","resources/mpackage.json"];
hashes = repmat(struct('path',"",'sha256',""),numel(names),1);
for iName = 1:numel(names)
    hashes(iName).path = names(iName);
    hashes(iName).sha256 = fileSHA256(fullfile(root,names(iName)));
end
end

function files = generatedMexFiles(root)
entries = dir(fullfile(root,"*."+mexext));
files = sort(string({entries.name}));
end

function root = resolveOceanKitRoot(repositoryRoot,requestedRoot)
if strlength(requestedRoot) > 0
    candidates = canonicalPath(requestedRoot);
else
    candidates = [canonicalPath(fullfile(repositoryRoot,"..","OceanKit")),canonicalPath(fullfile(repositoryRoot,"OceanKit"))];
end
root = "";
for candidate = candidates
    if isfile(fullfile(candidate,"tools","ci_release.m"))
        root = candidate;
        break
    end
end
if strlength(root) == 0
    error('FFTWTransforms:ReleaseGateOceanKitMissing','Unable to locate OceanKit/tools/ci_release.m.');
end
end

function [commit,tree] = sourceIdentity(root)
commit = gitValue(root,"rev-parse HEAD");
tree = gitValue(root,"rev-parse HEAD^{tree}");
end

function requireCleanTrackedTree(root)
[status,text] = system(sprintf('git -C "%s" status --porcelain --untracked-files=no',root));
if status ~= 0 || strlength(strtrim(string(text))) > 0
    error('FFTWTransforms:ReleaseGateDirtyTree','The tracked FFTWTransforms tree must be clean.');
end
end

function value = gitValue(root,arguments)
[status,text] = system(sprintf('git -C "%s" %s',root,arguments));
if status ~= 0
    error('FFTWTransforms:ReleaseGateGitFailure','Unable to run git %s.',arguments);
end
value = string(strtrim(text));
end

function assertCanonicalPlatform(required)
if required && ~isCanonicalPlatform
    error('FFTWTransforms:ReleaseGateUnsupportedPlatform','The canonical release gate requires MATLAB R2026a on maca64.');
end
end

function value = isCanonicalPlatform()
value = startsWith(string(version('-release')),"2026a",IgnoreCase=true) && string(computer('arch')) == "maca64";
end

function runCommand(command,identifier)
[status,output] = system(command);
if status ~= 0
    error(identifier,'%s',strtrim(output));
end
end

function requireEqual(actual,expected,identifier,message)
if ~isequal(string(actual),string(expected))
    error(identifier,'%s Expected %s, observed %s.',message,string(expected),string(actual));
end
end

function hash = fileSHA256(path)
fileID = fopen(path,'rb');
if fileID == -1
    error('FFTWTransforms:ReleaseGateReadFailed','Unable to read %s.',path);
end
cleanup = onCleanup(@() fclose(fileID));
bytes = fread(fileID,Inf,'*uint8');
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(bytes);
hashBytes = typecast(digest.digest(),'uint8');
hash = string(lower(reshape(dec2hex(hashBytes,2).',1,[])));
clear cleanup
end

function hash = textSHA256(text)
digest = java.security.MessageDigest.getInstance('SHA-256');
digest.update(unicode2native(char(text),'UTF-8'));
hashBytes = typecast(digest.digest(),'uint8');
hash = string(lower(reshape(dec2hex(hashBytes,2).',1,[])));
end

function value = canonicalPath(pathValue)
value = string(java.io.File(char(pathValue)).getCanonicalPath());
end

function timestamp = utcTimestamp()
timestamp = string(datetime('now',TimeZone='UTC',Format="yyyy-MM-dd'T'HH:mm:ss.SSS'Z'"));
end

function records = stackRecord(stack)
records = repmat(struct('name',"",'file',"",'line',0),numel(stack),1);
for iFrame = 1:numel(stack)
    records(iFrame).name = string(stack(iFrame).name);
    records(iFrame).file = string(stack(iFrame).file);
    records(iFrame).line = stack(iFrame).line;
end
end

function writeArtifacts(result,runDirectory)
writeText(fullfile(runDirectory,"release-gate.json"),string(jsonencode(result,PrettyPrint=true)));
writeText(fullfile(runDirectory,"summary.md"),markdownSummary(result));
end

function text = markdownSummary(result)
lines = strings(0,1);
lines(end+1) = "# FFTWTransforms release gate";
lines(end+1) = "";
lines(end+1) = "Status: **" + upper(result.status) + "**";
lines(end+1) = "";
lines(end+1) = "## Environment";
lines(end+1) = "";
lines(end+1) = "| Field | Value |";
lines(end+1) = "|---|---|";
lines(end+1) = row("MATLAB",result.environment.matlabVersion);
lines(end+1) = row("Architecture",result.environment.architecture);
lines(end+1) = row("Processor",result.environment.processor);
lines(end+1) = row("Physical memory",sprintf("%.1f GiB",result.environment.physicalMemoryBytes/2^30));
lines(end+1) = row("MEX compiler",result.environment.mexCompiler + " " + result.environment.mexCompilerVersion);
lines(end+1) = row("Candidate source",optional(result,"candidateSourceCommit"));
if isfield(result.exporter,'commit')
    lines(end+1) = row("OceanKit exporter commit",result.exporter.commit);
    lines(end+1) = row("Exporter SHA-256",result.exporter.sha256);
end
if isfield(result.capabilities,'provider')
    lines(end+1) = row("FFTW provider",result.capabilities.provider.id);
    lines(end+1) = row("FFTW version",result.capabilities.library.version);
    lines(end+1) = row("Resolved FFTW library",result.capabilities.library.resolvedPath);
end
if isfield(result.export,'hygiene')
    lines(end+1) = "";
    lines(end+1) = "## Export hygiene";
    lines(end+1) = "";
    lines(end+1) = "| Check | Result |";
    lines(end+1) = "|---|---|";
    lines(end+1) = row("Candidate version",result.package.exported.version);
    lines(end+1) = row("Pre-build payload digest",result.export.prebuildDigest);
    lines(end+1) = row("Forbidden files absent",yesNo(result.export.hygiene.passed));
end
if isfield(result.tests,'authoring')
    lines(end+1) = "";
    lines(end+1) = "## Tests";
    lines(end+1) = "";
    lines(end+1) = "| Tree | Passed | Failed | Incomplete | Seconds |";
    lines(end+1) = "|---|---:|---:|---:|---:|";
    lines(end+1) = testRow("Authoring",result.tests.authoring);
    if isfield(result.tests,'exported'), lines(end+1) = testRow("Exported",result.tests.exported); end
end
if isfield(result.numerics,'features')
    lines(end+1) = "";
    lines(end+1) = "## Numerical validation";
    lines(end+1) = "";
    lines(end+1) = "| Feature | Maximum relative error | Passed |";
    lines(end+1) = "|---|---:|---|";
    for feature = result.numerics.features'
        lines(end+1) = sprintf("| %s | %.3g | %s |",feature.id,feature.maximumRelativeError,yesNo(feature.passed)); %#ok<AGROW>
    end
end
if isfield(result.benchmarkHistory,'record')
    lines(end+1) = "";
    lines(end+1) = "## Benchmark history";
    lines(end+1) = "";
    lines(end+1) = "| Record | Value |";
    lines(end+1) = "|---|---|";
    lines(end+1) = row("History SHA-256",result.benchmarkHistory.sha256);
    lines(end+1) = row("Historical repository",result.benchmarkHistory.record.historicalRepository);
    lines(end+1) = row("Canonical benchmark issues","37, 38, 39, 41, 43");
end
if ~isempty(result.failure)
    lines(end+1) = "";
    lines(end+1) = "## Failure";
    lines(end+1) = "";
    lines(end+1) = "- Stage: `" + result.failure.stage + "`";
    lines(end+1) = "- Identifier: `" + result.failure.identifier + "`";
    lines(end+1) = "- Message: " + replace(result.failure.message,"|","\|");
end
text = join(lines,newline) + newline;
end

function value = optional(result,name)
if isfield(result,name) && strlength(string(result.(name))) > 0, value = string(result.(name)); else, value = "not recorded"; end
end

function line = row(label,value)
line = "| " + replace(string(label),"|","\|") + " | " + replace(string(value),"|","\|") + " |";
end

function line = testRow(label,summary)
line = sprintf("| %s | %d | %d | %d | %.2f |",label,summary.passed,summary.failed,summary.incomplete,summary.durationSeconds);
end

function value = yesNo(condition)
if condition, value = "yes"; else, value = "no"; end
end

function writeText(path,text)
fileID = fopen(path,'w');
if fileID == -1
    error('FFTWTransforms:ReleaseGateWriteFailed','Unable to write %s.',path);
end
cleanup = onCleanup(@() fclose(fileID));
fwrite(fileID,text,'char');
clear cleanup
end

function restoreState(directory,pathValue,planner,wisdom,threads,randomState,temporaryRoot)
try
    cd(directory);
catch
end
try
    path(pathValue);
catch
end
try
    fftw('dwisdom',[]);
    fftw('dwisdom',wisdom);
    fftw('planner',char(planner));
catch
end
try
    maxNumCompThreads(threads);
catch
end
try
    rng(randomState);
catch
end
if isfolder(temporaryRoot)
    try
        rmdir(temporaryRoot,'s');
    catch
    end
end
end
