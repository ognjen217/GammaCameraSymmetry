function [slope, intercept] = defineAxis(I, ax, fig)
% DEFINEAXIS  Unos tačaka i fit prave; prikaz prave isečene na granicama slike

    if nargin < 3 || isempty(fig)
        fig = ancestor(ax,'figure');
    end

    % Prikaži sliku u istim osama bez "odzumiranja"
    imshow(I, [], 'Parent', ax);
    axis(ax,'ij'); axis(ax,'image');

    % --- dodatni catch blokovi (tihi fallback, bez rušenja GUI-ja)
    try
        disableDefaultInteractivity(ax);
    catch ME 
        % ignoriši ako nije dostupno (starije verzije MATLAB-a)
    end
    try
        ax.Toolbar = [];
    catch ME 
        % ignoriši ako UIAxes nema Toolbar svojstvo u vašoj verziji
    end

    set(ax, 'HitTest','on', 'PickableParts','all', 'ButtonDownFcn', @onClick);
    imh = findobj(ax,'Type','image');
    set(imh,'HitTest','on', 'PickableParts','all', 'ButtonDownFcn', @onClick);

    ptsX = [];  ptsY = [];
    hold(ax,'on');
    hPts  = plot(ax, NaN, NaN, 'go', 'MarkerFaceColor','g', 'MarkerSize',5, 'PickableParts','none');
    hSkic = plot(ax, NaN, NaN, 'g--', 'LineWidth',1, 'PickableParts','none');
    hLine = plot(ax, NaN, NaN, 'r-', 'LineWidth',2, 'PickableParts','none');
    hold(ax,'off');

    title(ax, 'Levi klik: tačka   |   Desni klik: kraj i fit linije');

    doneFlag = false;
    uiwait(fig);
    if doneFlag == false
        doneFlag = true;
    end

    if numel(ptsX) < 2
        slope = 0; 
        intercept = size(I,1)/2; % fallback: horizontalna sredina
    else
        p = polyfit(ptsX, ptsY, 1); % y = m x + b
        slope = p(1); 
        intercept = p(2);
    end

    % Nacrtaj isečenu osu
    [xseg,yseg] = clipLineToImage(slope, intercept, size(I));
    set(hLine,'XData',xseg,'YData',yseg);

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
                p = polyfit(ptsX, ptsY, 1);
                [xseg,yseg] = clipLineToImage(p(1), p(2), size(I));
                set(hLine,'XData',xseg,'YData',yseg);
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
        % fallback: ostavi b=1
    end
end

function [xseg,yseg] = clipLineToImage(slope, intercept, imgSize)
    % Ista pomoćna funkcija kao u main_gui; lokalna kopija da ne zavisi od GUI-a
    H = imgSize(1); W = imgSize(2);
    m = slope; b = intercept;

    pts = [];
    y1 = m*1 + b;   if y1>=1 && y1<=H, pts(end+1,:) = [1, y1]; end 
    yW = m*W + b;   if yW>=1 && yW<=H, pts(end+1,:) = [W, yW]; end 
    if abs(m) > eps
        x1 = (1 - b)/m;  if x1>=1 && x1<=W, pts(end+1,:) = [x1, 1]; end 
        xH = (H - b)/m;  if xH>=1 && xH<=W, pts(end+1,:) = [xH, H]; end 
    else
        y = b; if y>=1 && y<=H, pts = [1,y; W,y]; end
    end
    if size(pts,1) > 2
        try
            [~,ia] = unique(round(pts,6),'rows','stable'); 
            pts = pts(ia,:);
            if size(pts,1) > 2
                D = squareform(pdist(pts));
                [~,ij] = max(D(:)); [i,j] = ind2sub(size(D),ij); 
                pts = pts([i j],:);
            end
        catch
            % ako nema Statistics/PDIST, samo uzmi prva dva preseka
            pts = pts(1:2,:);
        end
    end
    if size(pts,1) < 2
        xseg = [1 W]; yseg = [m*1+b, m*W+b];
    else
        xseg = pts(:,1)'; yseg = pts(:,2)';
    end
end
