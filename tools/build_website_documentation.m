function build_website_documentation(options)
arguments
    options.rootDir = ".."
end

repositoryRoot = string(java.io.File(char(options.rootDir)).getCanonicalPath());
sourceFolder = fullfile(repositoryRoot,"Documentation","WebsiteDocumentation");
destinationFolder = fullfile(repositoryRoot,"docs");
stagingRoot = string(tempname(fileparts(repositoryRoot)));
mkdir(stagingRoot);
stagingCleanup = onCleanup(@() removeFolderIfPresent(stagingRoot));
stagingFolder = fullfile(stagingRoot,"docs");

[copied,message] = copyfile(sourceFolder,stagingFolder);
if ~copied
    error('FFTWTransforms:DocumentationCopyFailed','Unable to stage documentation: %s',message);
end

changelogPath = fullfile(repositoryRoot,"CHANGELOG.md");
if isfile(changelogPath)
    header = "---" + newline + "layout: default" + newline + "title: Version History" + newline + "nav_order: 100" + newline + "---" + newline + newline;
    writeTextFile(fullfile(stagingFolder,"version-history.md"),header + string(fileread(changelogPath)));
end

removeFolderIfPresent(destinationFolder);
[moved,message] = movefile(stagingFolder,destinationFolder);
if ~moved
    error('FFTWTransforms:DocumentationInstallFailed','Unable to install generated documentation: %s',message);
end

clear stagingCleanup
fprintf("Website documentation rebuilt at %s\n",destinationFolder);
end

function writeTextFile(path,text)
fileID = fopen(path,'w');
if fileID == -1
    error('FFTWTransforms:DocumentationWriteFailed','Unable to write %s.',path);
end
fileCleanup = onCleanup(@() fclose(fileID));
fwrite(fileID,text,'char');
clear fileCleanup
end

function removeFolderIfPresent(folderPath)
if isfolder(folderPath)
    rmdir(folderPath,'s');
end
end
