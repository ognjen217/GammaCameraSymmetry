function [slope, intercept] = defineAxis(I, ax, fig)
% DEFINEAXIS – Interaktivno: levi klik dodaje tačke, DESNI klik završava.
% Radi na uifigure. Vraća pravu y = slope*x + intercept dobijenu fitom.

    if nargin < 3
        % fallback ako neko pozove starim potpisom
        fig = ancestor(ax,'figure');
    end

    imshow(I, [], 'Parent', ax);
    title(ax, 'Levi klik: dodaj tačku. Desni klik: završetak i fit linije.');

    ptsX = []; ptsY = [];
    hPts = []; hLine = [];
    doneFlag = false;

    % Sačuvaj prethodni handler i postavi naš
    oldFcn = fig.WindowButtonDownFcn;
    fig.WindowButtonDownFcn = @onMouseDown;

    % Čekaj korisnika
    uiwait(fig);

    % Vrati prethodni handler
    try, fig.WindowButtonDownFcn = oldFcn; catch, end

    if numel(ptsX) < 2
        error('Potrebno je označiti najmanje 2 tačke.');
    end

    p = polyfit(ptsX, ptsY, 1);
    slope = p(1); intercept = p(2);

    % iscrtaj krajnju pravu
    xvals = linspace(1, size(I,2), 200);
    yvals = slope * xvals + intercept;
    hold(ax, 'on');
    plot(ax, xvals, yvals, 'r-', 'LineWidth', 2);
    hold(ax, 'off');

    % ------- ugnježdena funkcija: klik handler -------
    function onMouseDown(src, event)
        cp = ax.CurrentPoint;
        x = cp(1,1); y = cp(1,2);
        xlim_ = xlim(ax); ylim_ = ylim(ax);
        inside = x>=xlim_(1) && x<=xlim_(2) && y>=ylim_(1) && y<=ylim_(2);
        if ~inside
            return;
        end

        switch event.Button
            case 1  % levi klik -> dodaj tačku
                ptsX(end+1) = x; %#ok<AGROW>
                ptsY(end+1) = y; %#ok<AGROW>
                hold(ax,'on');
                if isempty(hPts) || ~isvalid(hPts)
                    hPts = plot(ax, ptsX, ptsY, 'yo', 'MarkerFaceColor','y', 'MarkerSize',5);
                else
                    set(hPts, 'XData', ptsX, 'YData', ptsY);
                end
                if numel(ptsX) >= 2
                    if isempty(hLine) || ~isvalid(hLine)
                        hLine = plot(ax, ptsX, ptsY, 'y-', 'LineWidth', 1);
                    else
                        set(hLine, 'XData', ptsX, 'YData', ptsY);
                    end
                end
                hold(ax,'off');

            case 3  % desni klik -> završetak
                doneFlag = true;
        end

        if doneFlag
            uiresume(src);
        end
    end
end
