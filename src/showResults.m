function showResults(I, mismatchMask, ~, ax, ~, matchMask, metrics)

    if nargin < 6 || isempty(matchMask), matchMask = []; end
    if nargin >= 7 && isstruct(metrics) && isfield(metrics,'match_mask') && ~isempty(metrics.match_mask)
        matchMask = metrics.match_mask;
    end

    imshow(I, [], 'Parent', ax);
    hold(ax, 'on');

    if ~isempty(matchMask)
        h1 = imshow(matchMask, 'Parent', ax);
        green = [40,141,70]/255;                  % #288d46
        A1 = zeros(size(matchMask)); A1(matchMask) = 0.25;
        set(h1,'AlphaData',A1);
        set(h1,'CData',cat(3, green(1)*ones(size(matchMask)), ...
                               green(2)*ones(size(matchMask)), ...
                               green(3)*ones(size(matchMask))));
    end

    h2 = imshow(mismatchMask, 'Parent', ax);
    A2 = zeros(size(mismatchMask)); A2(mismatchMask) = 0.35;
    set(h2,'AlphaData',A2);
    set(h2,'CData',cat(3, ones(size(mismatchMask)), zeros(size(mismatchMask)), zeros(size(mismatchMask))));

    if nargin >= 7 && isstruct(metrics)
        txt = composeInfo(metrics);
        if ~isempty(txt)
            text(ax, 8, 16, txt, 'Color','w', 'FontSize',10, 'FontWeight','bold', ...
                'Interpreter','none', 'HorizontalAlignment','left', 'VerticalAlignment','top', ...
                'BackgroundColor',[0 0 0 0.30], 'Margin',6);
        end
    end

    hold(ax, 'off');
end

function s = composeInfo(M)
    fields = {'ssim','dice_edges','symmetry_score','match_frac'};
    labels = {'SSIM','Dice (edges)','Score','Match frac'};
    vals = cell(1,numel(fields));
    for i=1:numel(fields)
        if isfield(M,fields{i}) && ~isempty(M.(fields{i})) && ~isnan(M.(fields{i}))
            if strcmp(fields{i},'symmetry_score'), vals{i} = sprintf('%.1f',M.(fields{i}));
            else, vals{i} = sprintf('%.3f', M.(fields{i}));
            end
        else
            vals{i} = 'n/a';
        end
    end
    s = sprintf('%s: %s\n%s: %s\n%s: %s\n%s: %s', ...
        labels{1},vals{1}, labels{2},vals{2}, labels{3},vals{3}, labels{4},vals{4});
    if isfield(M,'significant') && ~isempty(M.significant)
        s = sprintf('%s\nSignificant: %s', s, tern(M.significant,'YES','NO'));
    end
end

function t = tern(c,a,b)
    if c, t=a; else, t=b; end
end
