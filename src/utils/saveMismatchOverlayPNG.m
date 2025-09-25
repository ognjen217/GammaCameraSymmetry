function saveMismatchOverlayPNG(outDir, baseName, I, mask)
%SAVEMISMATCHOVERLAYPNG Exportuje PNG sa overlay-em maskom nepoklapanja.
    ensureDir(outDir);
    RGB = simpleOverlay(I, mask);
    imwrite(RGB, fullfile(outDir, ['overlay_' stripExt(baseName) '.png']));
end
