function showResults(I, mismatchMask, ~, ax, ~, matchMask)
% Prikaz: zeleno (#288d46) = poklapanje; crveno = nepoklapanje.

    if nargin < 6, matchMask = []; end

    imshow(I, [], 'Parent', ax); hold(ax, 'on');

    % Zeleno – poklapanje
    if ~isempty(matchMask)
        h1 = imshow(matchMask, 'Parent', ax);
        green = [40,141,70]/255;                 % #288d46
        A1 = zeros(size(matchMask)); A1(matchMask) = 0.25;
        set(h1,'AlphaData',A1);
        set(h1,'CData',cat(3, green(1)*ones(size(matchMask)), ...
                               green(2)*ones(size(matchMask)), ...
                               green(3)*ones(size(matchMask))));
    end

    % Crveno – nepoklapanje
    h2 = imshow(mismatchMask, 'Parent', ax);
    A2 = zeros(size(mismatchMask)); A2(mismatchMask) = 0.35;
    set(h2,'AlphaData',A2);
    set(h2,'CData',cat(3, ones(size(mismatchMask)), zeros(size(mismatchMask)), zeros(size(mismatchMask))));

    hold(ax, 'off');
end
