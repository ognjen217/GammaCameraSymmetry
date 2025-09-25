function saveResultsMAT(outDir, baseName, res, extras)
    ensureDir(outDir);
    S = struct();
    S.file       = baseName;
    S.timestamp  = timestamp();
    S.results    = res;
    if nargin >= 4 && isstruct(extras)
        S.extras = extras;
    end
    save(fullfile(outDir, [stripExt(baseName) '.mat']), '-struct', 'S');
end
