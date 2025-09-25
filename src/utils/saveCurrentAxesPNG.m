function saveCurrentAxesPNG(outDir, baseName, ax)
%SAVECURRENTAXESPNG Snima trenutni prikaz osa kao PNG.
    ensureDir(outDir);
    fn = fullfile(outDir, ['view_' stripExt(baseName) '.png']);
    exportgraphics(ax, fn, 'Resolution', 150);
end
