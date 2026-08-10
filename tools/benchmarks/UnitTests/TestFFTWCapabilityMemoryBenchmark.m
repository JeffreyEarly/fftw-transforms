classdef TestFFTWCapabilityMemoryBenchmark < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addBenchmarkPath(testCase)
            benchmarkDirectory = fileparts(fileparts(mfilename('fullpath')));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(benchmarkDirectory));
        end
    end

    methods (Test)
        function testFreshProcessSmokeAndArtifacts(testCase)
            import matlab.unittest.fixtures.TemporaryFolderFixture
            fixture = testCase.applyFixture(TemporaryFolderFixture);
            result = runFFTWCapabilityMemoryBenchmark(baselineRef="v1.0.2",candidateRef="v1.0.2",scenarios="no-query",nRuns=1,outputDirectory=string(fixture.Folder),runId="smoke",requireCleanTree=false);

            testCase.verifyEqual(result.status,"passed");
            testCase.verifyNumElements(result.implementations,2);
            for implementation = result.implementations.'
                testCase.verifyNumElements(implementation.runs,1);
                testCase.verifyEqual(implementation.runs.status,"passed");
                testCase.verifyEqual(string({implementation.runs.phases.name}),["startup","no-query-control"]);
                testCase.verifyTrue(all([implementation.runs.phases.workerRSSBytes] > 0));
                testCase.verifyTrue(all([implementation.runs.phases.workerProcessId] > 0));
            end
            testCase.verifyTrue(isfile(result.artifacts.json));
            testCase.verifyTrue(isfile(result.artifacts.markdown));
            decoded = jsondecode(fileread(result.artifacts.json));
            testCase.verifyEqual(string(decoded.status),"passed");
            summary = string(fileread(result.artifacts.markdown));
            testCase.verifyTrue(contains(summary,"RSS comparison"));
            testCase.verifyTrue(contains(summary,"Java-state evidence"));
        end
    end
end
