function paths = fftwBenchmarkPaths()
% Return authoring paths used by the quarantined FFTW benchmarks.
%
% Benchmark code is intentionally outside the runtime package. This helper
% keeps benchmark sources, results, and build products independent of the
% current working directory while locating production headers at the
% repository root.

paths.benchmarkDirectory = string(fileparts(mfilename('fullpath')));
paths.toolsDirectory = string(fileparts(paths.benchmarkDirectory));
paths.repositoryRoot = string(fileparts(paths.toolsDirectory));
paths.runtimeSourceDirectory = paths.repositoryRoot;
paths.resultDirectory = fullfile(paths.benchmarkDirectory,"results");
paths.buildDirectory = fullfile(paths.benchmarkDirectory,"build");
paths.unitTestDirectory = fullfile(paths.benchmarkDirectory,"UnitTests");
end
