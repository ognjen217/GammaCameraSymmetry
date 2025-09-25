function showResults(I, mismatchMask, res, ax, tbl)
    imshow(I, [], 'Parent', ax);
    hold(ax, 'on');
    h = imshow(mismatchMask, 'Parent', ax);
    set(h, 'AlphaData', 0.3);
    hold(ax, 'off');

    tbl.Data = {res.numMismatch, res.shift, res.areaRatio};
    tbl.ColumnName = {'Nepoklapanja','Pomeraj','Odnos povrsina'};
end
