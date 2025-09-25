function dirs = getDefaultDirs()
%GETDEFAULTDIRS Standardne putanje projekta (kreira results/ ako ne postoji).

    here       = mfilename('fullpath');
    utilsDir   = fileparts(here);          % .../src/utils
    srcDir     = fileparts(utilsDir);      % .../src
    projectRoot= fileparts(srcDir);        % .../project_root

    % fallback ako je struktura atipična
    if ~exist(fullfile(projectRoot,'data'),'dir') && exist(fullfile(srcDir,'data'),'dir')
        projectRoot = srcDir;
    end

    dataDir         = fullfile(projectRoot, 'data');
    dataOriginalDir = fullfile(dataDir, 'original_images');
    resultsDir      = fullfile(projectRoot, 'results');
    figsDir         = fullfile(resultsDir, 'figures');
    docsDir         = fullfile(projectRoot, 'docs');

    ensureDir(resultsDir);
    ensureDir(figsDir);

    dirs = struct('projectRoot',projectRoot, ...
                  'data',dataDir, ...
                  'data_original',dataOriginalDir, ...
                  'results',resultsDir, ...
                  'figures',figsDir, ...
                  'docs',docsDir);
end
