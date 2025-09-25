function saveHeatMapPNG(outDir, baseName, diffAbs)
    ensureDir(outDir);
    A = mat2gray(diffAbs);
    cmap = parula(256);
    RGB = ind2rgb(gray2ind(A,256), cmap);
    imwrite(RGB, fullfile(outDir, ['heatmap_' stripExt(baseName) '.png']));
end
