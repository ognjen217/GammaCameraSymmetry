function dirs = getDefaultDirs()
%GETDEFAULTDIRS Vraća standardne projektne putanje i kreira ih ako ne postoje.
%  dirs.projectRoot
%  dirs.data, dirs.results, dirs.figures, dirs.docs, ...
%
% Radi bez obzira odakle se poziva (GUI/batch).

    % Pronađi src/ iz ove funkcije i onda project_root
    here = mfilename('fullpath');
    srcDir = fileparts(here);                  % .../src/utils
    srcDir = fileparts(srcDir);                % .../src
    projectRoot = fileparts(srcDir);           % .../project_root

    % Fallback: ako neko menja raspored, pokušaj samo jedan nivo iznad
    if ~exist(fullfile(projectRoot,'data'),'dir') && exist(fullfile(srcDir,'data'),'dir')
        projectRoot = srcDir;
    end

    dataDir    = fullfile(projectRoot, 'data');
    resultsDir = fullfile(projectRoot, 'results');
    figsDir    = fullfile(resultsDir, 'figures');
    docsDir    = fullfile(projectRoot, 'docs');

    ensureDir(resultsDir);
    ensureDir(figsDir);

    dirs = struct('projectRoot',projectRoot, ...
                  'data',dataDir, ...
                  'results',resultsDir, ...
                  'figures',figsDir, ...
                  'docs',docsDir);
end
