function saveCurrentAxesPNG(outDir, baseName, ax)
    ensureDir(outDir);
    fn = fullfile(outDir, ['view_' stripExt(baseName) '.png']);
    exportgraphics(ax, fn, 'Resolution', 150);
end
