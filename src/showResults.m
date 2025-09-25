function showResults(I, mismatchMask, res, ax, tbl)
%SHOWRESULTS Prikaz slike sa poluprovidnim overlay-em maskom nepoklapanja.
% Ne menja tabelu (tbl) – tabela se popunjava u main_gui.
    imshow(I, [], 'Parent', ax);
    hold(ax, 'on');
    h = imshow(mismatchMask, 'Parent', ax);
    set(h, 'AlphaData', 0.3);
    hold(ax, 'off');
end
% ------------------------------------------------------------
% --- IGNORE ---
