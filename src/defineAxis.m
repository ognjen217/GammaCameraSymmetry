function [slope, intercept] = defineAxis(I, ax, fig)

    if nargin < 3 || isempty(fig)
        fig = ancestor(ax,'figure');
    end

    imh = imshow(I, [], 'Parent', ax);
    title(ax, 'Levi klik: tačka   |   Desni klik: kraj i fit linije');
    try, disableDefaultInteractivity(ax); end     
    try, ax.Toolbar = []; end                     

    set(ax, 'HitTest','on', 'PickableParts','all', 'ButtonDownFcn', @onClick);
    set(imh,'HitTest','on', 'PickableParts','all', 'ButtonDownFcn', @onClick);

    ptsX = [];  ptsY = [];
    hold(ax,'on');
    hPts  = plot(ax, nan, nan, 'yo', 'MarkerFaceColor','y', 'MarkerSize',5, 'PickableParts','none');
    hSkic = plot(ax, nan, nan, 'y-', 'LineWidth',1, 'PickableParts','none');
    hold(ax,'off');

    doneFlag = false;
    uiwait(fig);                           

    if isvalid(ax), set(ax, 'ButtonDownFcn',[]); end
    if isgraphics(imh), set(imh,'ButtonDownFcn',[]); end

    if numel(ptsX) < 2
        error('Potrebno je označiti najmanje 2 tačke.');
    end

    p = polyfit(ptsX, ptsY, 1);
    slope = p(1); intercept = p(2);

    xvals = linspace(1, size(I,2), 200);
    yvals = slope * xvals + intercept;
    hold(ax, 'on');
    plot(ax, xvals, yvals, 'r-', 'LineWidth', 2, 'PickableParts','none');
    hold(ax, 'off');


    function onClick(~, ev)
        cp = ax.CurrentPoint;
        x  = cp(1,1);  y = cp(1,2);
        xl = xlim(ax); yl = ylim(ax);
        inside = x>=xl(1) && x<=xl(2) && y>=yl(1) && y<=yl(2);
        if ~inside, return; end

        btn = detectButton(ev, fig);

        if btn == 1
            ptsX(end+1) = x; 
            ptsY(end+1) = y; 
            set(hPts,  'XData', ptsX, 'YData', ptsY);
            if numel(ptsX) >= 2
                set(hSkic, 'XData', ptsX, 'YData', ptsY);
            end
        elseif btn == 3
            doneFlag = true;
            uiresume(fig);
        end
    end
end

function b = detectButton(ev, fig)
    b = 1;
    try
        if isobject(ev) && isprop(ev,'Button')
            b = ev.Button; return;
        end
        switch get(fig,'SelectionType')
            case 'normal', b = 1;
            case 'alt',    b = 3;
            case 'extend', b = 2;
            otherwise,     b = 1;
        end
    catch
    end
end
