function [numMismatch, shift, areaRatio, mismatchMask] = compareSymmetry(I, Iref)
    I    = im2double(I);
    Iref = im2double(Iref);

    diff = abs(I - Iref);
    thresh = mean(diff(:)) + std(diff(:));
    mismatchMask = diff > thresh;
    numMismatch = sum(mismatchMask(:));

    BW = mismatchMask;
    CC = bwconncomp(BW);
    stats = regionprops(CC, 'Centroid', 'Area');

    if numel(stats) >= 2
        [~, idxs] = sort([stats.Area], 'descend');
        c1 = stats(idxs(1)).Centroid;
        c2 = stats(idxs(2)).Centroid;
        shift = norm(c1 - c2);
        areaRatio = stats(idxs(1)).Area / stats(idxs(2)).Area;
    else
        shift = NaN;
        areaRatio = NaN;
    end
end
