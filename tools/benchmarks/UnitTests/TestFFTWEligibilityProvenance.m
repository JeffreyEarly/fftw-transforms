classdef TestFFTWEligibilityProvenance < matlab.unittest.TestCase
    methods (TestClassSetup)
        function configurePaths(testCase)
            paths = TestFFTWEligibilityProvenance.paths;
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(paths.benchmarkDirectory));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(paths.repositoryRoot));
        end
    end

    methods (Test)
        function testStaticEligibilityMatchesCanonicalArtifacts(testCase)
            paths = TestFFTWEligibilityProvenance.paths;
            capabilities = FFTWBackend.capabilities();
            issue41 = jsondecode(fileread(fullfile(paths.repositoryRoot,capabilities.eligibility.horizontal.sourceArtifact)));
            issue43 = jsondecode(fileread(fullfile(paths.repositoryRoot,capabilities.eligibility.realToReal.sourceArtifact)));

            testCase.verifyTrue(issue41.readiness.ready);
            testCase.verifyEqual(capabilities.eligibility.horizontal.gateSizes,issue41.configuration.gateSizes);
            testCase.verifyEqual(capabilities.eligibility.horizontal.thresholds.rawForwardSpeedup,issue41.configuration.thresholds.rawForwardSpeedRatio);
            testCase.verifyEqual(capabilities.eligibility.horizontal.thresholds.completeForwardSpeedup,issue41.configuration.thresholds.totalForwardSpeedRatio);
            testCase.verifyEqual(capabilities.eligibility.horizontal.thresholds.destructiveInverseSpeedRatio,issue41.configuration.thresholds.inverseSpeedRatio);

            records = capabilities.eligibility.realToReal.records;
            testCase.verifyNumElements(issue43.eligibility,numel(records));
            for record = records'
                artifact = issue43.eligibility([issue43.eligibility.Nz] == record.Nz & string({issue43.eligibility.dataType}) == record.dataType & string({issue43.eligibility.transformType}) == record.transformType & string({issue43.eligibility.direction}) == record.direction);
                testCase.verifyNumElements(artifact,1);
                testCase.verifyEqual(record.eligible,artifact.eligible);
                testCase.verifyEqual(record.testedBatchCounts,artifact.testedBatchCounts(:).');
                if record.eligible
                    testCase.verifyEqual(record.intervals.minimumBatchCount,artifact.intervals.minimumBatchCount);
                    testCase.verifyEqual(record.intervals.maximumBatchCount,artifact.intervals.maximumBatchCount);
                else
                    testCase.verifyEmpty(record.intervals);
                end
            end
        end
    end

    methods (Static, Access=private)
        function paths = paths()
            benchmarkDirectory = fileparts(fileparts(mfilename('fullpath')));
            paths.benchmarkDirectory = benchmarkDirectory;
            paths.repositoryRoot = fileparts(fileparts(benchmarkDirectory));
        end
    end
end
