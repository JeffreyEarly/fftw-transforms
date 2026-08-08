function history = fftwBenchmarkRunHistory()
% Identify the active package source and its extracted GL source record.

paths = fftwBenchmarkPaths;
history.productionRepository = "JeffreyEarly/fftw-transforms";
history.currentCommit = gitValue(paths.repositoryRoot,"rev-parse HEAD");
history.currentTree = gitValue(paths.repositoryRoot,"rev-parse HEAD^{tree}");
[status,dirtyText] = system(sprintf('git -C "%s" status --porcelain --untracked-files=all',paths.repositoryRoot));
history.currentWorkingTreeDirty = status ~= 0 || strlength(strtrim(string(dirtyText))) > 0;
history.extraction.historicalRepository = "JeffreyEarly/GLNumericalModelingKit";
history.extraction.historicalPath = "Matlab/Spectral/FFTW";
history.extraction.sourceCommit = "3c5fce2b2df9c892418676ef75ffbc5752216e55";
history.extraction.sourceTree = "d8f8e58de659f8c0af8400c003ca98ab9529e1d5";
history.extraction.filteredTip = "0281a11f0b6ba32d782bb5887460e1661b6a8bcf";
end

function value = gitValue(repositoryRoot,arguments)
[status,text] = system(sprintf('git -C "%s" %s',repositoryRoot,arguments));
if status == 0
    value = string(strtrim(text));
else
    value = "unknown";
end
end
