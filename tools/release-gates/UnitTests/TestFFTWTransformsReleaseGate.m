classdef TestFFTWTransformsReleaseGate < matlab.unittest.TestCase
    methods (Test)
        function testCommittedCanonicalArtifact(testCase)
            root = TestFFTWTransformsReleaseGate.repositoryRoot;
            entries = dir(fullfile(root,"tools","release-gates","results","*","release-gate.json"));
            testCase.verifyNumElements(entries,1,"Exactly one canonical release-gate artifact is required.");
            artifactPath = fullfile(entries(1).folder,entries(1).name);
            artifact = jsondecode(fileread(artifactPath));

            testCase.verifyEqual(string(artifact.status),"passed");
            testCase.verifyEqual(string(artifact.candidateVersion),"1.0.0");
            testCase.verifyTrue(artifact.environment.canonicalPlatform);
            testCase.verifyEqual(string(artifact.environment.architecture),"maca64");
            testCase.verifyEqual(string(artifact.source.commit),string(artifact.candidateSourceCommit));
            testCase.verifyEqual(string(artifact.package.authoring.version),"0.1.0");
            testCase.verifyEqual(string(artifact.package.exported.version),"1.0.0");
            testCase.verifyEqual(string(artifact.package.authoring.id),string(artifact.package.exported.id));
            testCase.verifyEqual(string(artifact.capabilities.provider.id),"matlab-bundled");
            testCase.verifyEqual(string(artifact.capabilities.library.version),"fftw-3.3.8");
            testCase.verifyTrue(artifact.validation.passed);
            testCase.verifyTrue(artifact.export.hygiene.passed);
            testCase.verifyLessThanOrEqual(artifact.numerics.maximumRelativeError,1e-12);
            testCase.verifyGreaterThan(artifact.tests.authoring.passed,0);
            testCase.verifyGreaterThan(artifact.tests.exported.passed,0);

            historyPath = fullfile(root,artifact.benchmarkHistory.path);
            testCase.verifyEqual(TestFFTWTransformsReleaseGate.fileSHA256(historyPath),string(artifact.benchmarkHistory.sha256));
            currentPackage = matlab.mpm.Package(root);
            currentVersion = string(currentPackage.Version);
            testCase.verifyEqual(string(currentPackage.ID),string(artifact.package.authoring.id));
            if currentVersion == string(artifact.package.authoring.version)
                for record = reshape(artifact.runtimeHashes,1,[])
                    testCase.verifyEqual(TestFFTWTransformsReleaseGate.fileSHA256(fullfile(root,record.path)),string(record.sha256));
                end
            else
                current = currentPackage.Version;
                released = matlab.mpm.Version(string(artifact.package.exported.version));
                testCase.verifyGreaterThanOrEqual([current.Major current.Minor current.Patch],[released.Major released.Minor released.Patch]);
            end

        end
    end

    methods (Static, Access=private)
        function root = repositoryRoot()
            root = fileparts(fileparts(fileparts(fileparts(mfilename('fullpath')))));
        end

        function hash = fileSHA256(path)
            fileID = fopen(path,'rb');
            if fileID == -1
                error('FFTWTransforms:ReleaseGateTestReadFailed','Unable to read %s.',path);
            end
            cleanup = onCleanup(@() fclose(fileID));
            bytes = fread(fileID,Inf,'*uint8');
            digest = java.security.MessageDigest.getInstance('SHA-256');
            digest.update(bytes);
            hashBytes = typecast(digest.digest(),'uint8');
            hash = string(lower(reshape(dec2hex(hashBytes,2).',1,[])));
            clear cleanup
        end
    end
end
