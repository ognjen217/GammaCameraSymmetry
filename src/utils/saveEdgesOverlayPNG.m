function saveEdgesOverlayPNG(outDir, baseName, Igray, E1, E2)
    ensureDir(outDir);
    I = mat2gray(Igray);
    [H,W] = size(I);
    RGB = repmat(I,[1 1 3]);

    RGB(:,:,3) = max(RGB(:,:,3), double(E1));

    RGB(:,:,1) = max(RGB(:,:,1), double(E2));
    RGB(:,:,2) = max(RGB(:,:,2), double(E2));

    k = 0.85; RGB = k*RGB + (1-k);
    imwrite(RGB, fullfile(outDir, ['edges_' stripExt(baseName) '.png']));
end
