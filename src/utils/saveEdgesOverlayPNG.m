function saveEdgesOverlayPNG(outDir, baseName, Igray, E1, E2)
% Siva slika + plave ivice originala + žute ivice refleksije
    ensureDir(outDir);
    I = mat2gray(Igray);
    [H,W] = size(I);
    RGB = repmat(I,[1 1 3]);
    % plavo za E1
    RGB(:,:,3) = max(RGB(:,:,3), double(E1));
    % žuto za E2 (R+G)
    RGB(:,:,1) = max(RGB(:,:,1), double(E2));
    RGB(:,:,2) = max(RGB(:,:,2), double(E2));
    % lakša vidljivost
    k = 0.85; RGB = k*RGB + (1-k);
    imwrite(RGB, fullfile(outDir, ['edges_' stripExt(baseName) '.png']));
end
