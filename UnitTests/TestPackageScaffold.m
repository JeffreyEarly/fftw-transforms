classdef TestPackageScaffold < matlab.unittest.TestCase
    methods (TestClassSetup)
        function addRepositoryToPath(testCase)
            import matlab.unittest.fixtures.PathFixture
            testCase.applyFixture(PathFixture(TestPackageScaffold.repositoryRoot));
        end
    end

    methods (Test)
        function testPackageManifest(testCase)
            package = matlab.mpm.Package(TestPackageScaffold.repositoryRoot);
            testCase.verifyEqual(package.Name,"FFTWTransforms");
            testCase.verifyEqual(package.DisplayName,"FFTWTransforms");
            testCase.verifyEqual(package.Version,matlab.mpm.Version("0.1.0"));
            testCase.verifyEqual(string(package.ReleaseCompatibility),">=R2024b");
            testCase.verifyEqual(package.Summary,"Reusable FFTW transforms for MATLAB.");
            testCase.verifyEmpty(package.Dependencies);
            testCase.verifyEmpty(package.Folders);
            testCase.verifyNotEmpty(regexp(package.ID,"^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$",'once'));
        end

        function testLicensingAndAuthoringFiles(testCase)
            root = TestPackageScaffold.repositoryRoot;
            header = string(fileread(fullfile(root,"fftw3.h")));
            notices = string(fileread(fullfile(root,"THIRD_PARTY_NOTICES.md")));
            readme = string(fileread(fullfile(root,"README.md")));
            testCase.verifyTrue(contains(header,"license applies *only* to this header file"));
            testCase.verifyTrue(contains(notices,"Copyright (c) 2003, 2007-14 Matteo Frigo"));
            testCase.verifyTrue(contains(notices,"GNU General Public License"));
            testCase.verifyTrue(contains(readme,"does not distribute FFTW libraries"));
            testCase.verifyTrue(isfile(fullfile(root,"LICENSE")));
            testCase.verifyTrue(isfile(fullfile(root,"CHANGELOG.md")));
            testCase.verifyFalse(isfile(fullfile(root,"tools","ci_release.m")));
        end

        function testStructuredUnavailabilityDoesNotCompile(testCase)
            isPortableEnvironment = string(version('-release')) == "2025b" && string(computer('arch')) == "glnxa64";
            testCase.assumeTrue(isPortableEnvironment,"This test targets the portable Linux/R2025b CI environment.");

            before = TestPackageScaffold.generatedMexFiles;
            testCase.verifyWarningFree(@() FFTWBackend.capabilities());
            capabilities = FFTWBackend.capabilities();
            testCase.verifyEqual(capabilities.status,"unavailable");
            testCase.verifyEqual(capabilities.reason.code,"unsupported-release");
            testCase.verifyFalse(capabilities.build.attempted);
            testCase.verifyFalse(capabilities.build.isPossible);

            testCase.verifyWarningFree(@() FFTWBackend.build());
            buildResult = FFTWBackend.build();
            testCase.verifyEqual(buildResult.status,"unavailable");
            testCase.verifyTrue(buildResult.build.attempted);
            testCase.verifyFalse(buildResult.build.succeeded);
            testCase.verifyEqual(buildResult.build.reason.code,"unsupported-platform");
            testCase.verifyEqual(TestPackageScaffold.generatedMexFiles,before);
        end
    end

    methods (Static, Access=private)
        function root = repositoryRoot()
            testDirectory = fileparts(mfilename('fullpath'));
            root = fileparts(testDirectory);
        end

        function names = generatedMexFiles()
            files = dir(fullfile(TestPackageScaffold.repositoryRoot,"*."+mexext));
            names = sort(string({files.name}));
        end
    end
end
