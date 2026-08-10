function result = runFFTWCapabilityMemoryWorker(sourceRoot,scenario,runDirectory)
% Execute one fresh-process capability-memory scenario.

arguments (Input)
    sourceRoot (1,1) string
    scenario (1,1) string {mustBeMember(scenario,["no-query","java-control","compiler-control","lifecycle"])}
    runDirectory (1,1) string
end

mkdir(runDirectory);
result.schemaVersion = "1.0.0";
result.status = "running";
result.scenario = scenario;
result.processId = matlabProcessID;
result.sourceRoot = sourceRoot;
result.capabilities = struct;
result.failure = struct('identifier',"",'message',"",'stack',repmat(struct('file',"",'name',"",'line',0),0,1));
resultPath = fullfile(runDirectory,"worker-result.json");
cleanup = onCleanup(@() writeResult(resultPath,result));

try
    signalPhase(runDirectory,1,"startup");
    switch scenario
        case "no-query"
            version('-release');
            signalPhase(runDirectory,2,"no-query-control");
        case "java-control"
            java.io.File(char(sourceRoot)).getCanonicalPath();
            signalPhase(runDirectory,2,"java-positive-control");
        case "compiler-control"
            mex.getCompilerConfigurations('C++','Selected');
            signalPhase(runDirectory,2,"compiler-discovery-control");
        case "lifecycle"
            previousDirectory = string(pwd);
            directoryCleanup = onCleanup(@() cd(previousDirectory));
            cd(sourceRoot);
            addpath(sourceRoot,'-begin');
            result.capabilities.beforeBuild = FFTWBackend.capabilities();
            signalPhase(runDirectory,2,"capability-query");

            result.capabilities.afterBuild = FFTWBackend.build();
            if ~result.capabilities.afterBuild.isComplete
                error('FFTWCapabilityMemoryBenchmark:BuildFailed','The temporary snapshot did not build: %s',result.capabilities.afterBuild.build.reason.message);
            end
            signalPhase(runDirectory,3,"build-validation");

            transform = RealToComplexTransform([256 256 8],dims=[2 1],planner="estimate",nCores=1,alignmentMode="unaligned",plannerTimeLimitSeconds=1);
            transformCleanup = onCleanup(@() delete(transform));
            signalPhase(runDirectory,4,"plan-construction");

            rng(9,'twister');
            input = randn(256,256,8);
            spectrum = transform.transformForward(input); %#ok<NASGU>
            signalPhase(runDirectory,5,"first-transform");

            for iExecution = 1:7
                spectrum = transform.transformForward(input); %#ok<NASGU>
            end
            signalPhase(runDirectory,6,"repeated-transforms");

            clear transformCleanup transform spectrum
            signalPhase(runDirectory,7,"transform-deletion");

            clear fftw_r2c fftw_r2r
            rehash
            signalPhase(runDirectory,8,"mex-clearing");
            clear directoryCleanup
    end
    result.status = "passed";
catch exception
    result.status = "failed";
    result.failure.identifier = string(exception.identifier);
    result.failure.message = string(exception.message);
    result.failure.stack = exception.stack;
end
clear cleanup
writeResult(resultPath,result);
end

function signalPhase(runDirectory,index,name)
readyPath = fullfile(runDirectory,sprintf('%02d-%s.ready',index,name));
acknowledgementPath = fullfile(runDirectory,sprintf('%02d-%s.ack',index,name));
fileId = fopen(readyPath,'w');
if fileId < 0, error('FFTWCapabilityMemoryBenchmark:PhaseWriteFailed','Unable to write %s.',readyPath); end
fprintf(fileId,'%s\n',name);
fclose(fileId);
while ~isfile(acknowledgementPath)
    pause(0.02);
end
end

function writeResult(path,result)
fileId = fopen(path,'w');
if fileId < 0, return, end
cleanup = onCleanup(@() fclose(fileId));
fwrite(fileId,jsonencode(result,PrettyPrint=true),'char');
clear cleanup
end
