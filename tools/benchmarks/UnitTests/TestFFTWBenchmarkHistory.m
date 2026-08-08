classdef TestFFTWBenchmarkHistory < matlab.unittest.TestCase
    methods (TestClassSetup)
        function configurePaths(testCase)
            paths = TestFFTWBenchmarkHistory.paths;
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(paths.benchmarkDirectory));
            testCase.applyFixture(matlab.unittest.fixtures.PathFixture(paths.repositoryRoot));
        end
    end

    methods (Test)
        function testStaticEligibilityMatchesCanonicalArtifacts(testCase)
            paths = TestFFTWBenchmarkHistory.paths;
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

        function testCanonicalArtifactHashesAreFixed(testCase)
            paths = TestFFTWBenchmarkHistory.paths;
            history = jsondecode(fileread(fullfile(paths.benchmarkDirectory,"benchmark-history.json")));
            benchmarkRecords = history.records(strcmp({history.records.kind},'benchmark'));
            expectedIssues = [37 38 39 41 43];
            expectedJsonHashes = [
                "7301050b1e0d9d2df9f8a91bde3be22abad856dafb1c43672d0b857a18fa71bf"
                "1bbb30433322629859abda956b706417cb38e43bb93b16a210e2502a2785f1b8"
                "ef50fc2734a0d34fa0d0bf569f5bd347f3d6dd9dc0719353d9dc4c0c92ff2473"
                "f00ec5519529e2025806cf09a082dfc1dda4d45afce304affc9e943aa2fe4def"
                "85db2321a41b14eae867bbb57fcef25bbe931029b89b93a964ebe515f7d70a5d"
                ];
            expectedMarkdownHashes = [
                "84a8012da82d4d7d3994ce174667b1ebba77fcce4084ab872d5e07dfd193bd84"
                "e3c24709d2168b4225fbe5788d16bb2621acfc8ac48d430ca6d4cd0c94541f89"
                "bbc9504d477adcf9c1f6ac9882fdce067eb21c935b544cafb32f4d2dc1264cc2"
                "88fc4c02232c2db5e7f4bd04c5949c428e4deb4b7c99156f36166a4f0a28ca29"
                "90c827da0c7f77d55ed88dfa120f84d7d83a4bb8cfd447a75b5dcacbb421afa0"
                ];

            testCase.verifyEqual([benchmarkRecords.issue],expectedIssues);
            for iRecord = 1:numel(benchmarkRecords)
                record = benchmarkRecords(iRecord);
                testCase.verifyEqual(string(record.json.sha256),expectedJsonHashes(iRecord));
                testCase.verifyEqual(string(record.markdown.sha256),expectedMarkdownHashes(iRecord));
                testCase.verifyEqual(TestFFTWBenchmarkHistory.fileSHA256(fullfile(paths.repositoryRoot,record.json.path)),expectedJsonHashes(iRecord));
                testCase.verifyEqual(TestFFTWBenchmarkHistory.fileSHA256(fullfile(paths.repositoryRoot,record.markdown.path)),expectedMarkdownHashes(iRecord));
            end
        end

        function testCommitMappingsAndNonbenchmarkEntries(testCase)
            paths = TestFFTWBenchmarkHistory.paths;
            history = jsondecode(fileread(fullfile(paths.benchmarkDirectory,"benchmark-history.json")));
            mapText = string(fileread(fullfile(paths.repositoryRoot,history.extraction.commitMap)));
            lines = splitlines(strip(mapText));
            pairs = split(lines(2:end),char(9));
            sourceCommits = pairs(:,1);
            filteredCommits = pairs(:,2);

            mappedRecords = history.records(strlength(string({history.records.artifactCommit})) > 0);
            for iRecord = 1:numel(mappedRecords)
                record = mappedRecords(iRecord);
                index = find(sourceCommits == string(record.artifactCommit),1);
                testCase.verifyNotEmpty(index,"Missing source commit " + string(record.artifactCommit));
                testCase.verifyEqual(filteredCommits(index),string(record.filteredArtifactCommit));
            end

            issue40 = history.records([history.records.issue] == 40);
            issue42 = history.records([history.records.issue] == 42);
            testCase.verifyEqual(string(issue40.kind),"decision");
            testCase.verifyEqual(string(issue40.json.path),"");
            testCase.verifyEqual(string(issue42.kind),"production-code");
            testCase.verifyEqual(string(issue42.json.path),"");
        end

        function testRuntimeHistoryMatchesCanonicalRecord(testCase)
            capabilities = FFTWBackend.capabilities();
            paths = TestFFTWBenchmarkHistory.paths;
            history = jsondecode(fileread(fullfile(paths.benchmarkDirectory,"benchmark-history.json")));
            issue41 = history.records([history.records.issue] == 41);
            issue43 = history.records([history.records.issue] == 43);

            testCase.verifyEqual(capabilities.eligibility.horizontal.history.productionRepository,string(history.productionRepository));
            testCase.verifyEqual(capabilities.eligibility.horizontal.history.historicalRepository,string(history.historicalRepository));
            testCase.verifyEqual(capabilities.eligibility.horizontal.history.originalCommit,string(issue41.artifactCommit));
            testCase.verifyEqual(capabilities.eligibility.horizontal.history.filteredCommit,string(issue41.filteredArtifactCommit));
            testCase.verifyEqual(capabilities.eligibility.horizontal.history.artifactSHA256,string(issue41.json.sha256));
            testCase.verifyEqual(capabilities.eligibility.realToReal.history.originalCommit,string(issue43.artifactCommit));
            testCase.verifyEqual(capabilities.eligibility.realToReal.history.filteredCommit,string(issue43.filteredArtifactCommit));
            testCase.verifyEqual(capabilities.eligibility.realToReal.history.artifactSHA256,string(issue43.json.sha256));
        end
    end

    methods (Static, Access=private)
        function paths = paths()
            benchmarkDirectory = fileparts(fileparts(mfilename('fullpath')));
            paths.benchmarkDirectory = benchmarkDirectory;
            paths.repositoryRoot = fileparts(fileparts(benchmarkDirectory));
        end

        function hash = fileSHA256(path)
            fileID = fopen(path,'rb');
            if fileID == -1
                error('FFTWTransforms:HistoryReadFailed','Unable to read %s.',path);
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
