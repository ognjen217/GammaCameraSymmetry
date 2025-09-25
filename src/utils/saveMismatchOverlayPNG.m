function saveMismatchOverlayPNG(outDir, baseName, I, mask)
    ensureDir(outDir);
    RGB = simpleOverlay(I, mask);
    imwrite(RGB, fullfile(outDir, ['overlay_' stripExt(baseName) '.png']));
end
