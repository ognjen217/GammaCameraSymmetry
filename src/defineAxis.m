function [slope, intercept] = defineAxis(I, ax, fig)
% DEFINEAXIS – Levi klik dodaje tačke; DESNI klik završava crtanje.
% Robusno hvata klikove i na UIAxes i na samoj slici (imshow).

    if nargin < 3 || isempty(fig)
        fig = ancestor(ax,'figure');
    end

    % Prikaz slike i gašenje default interakcija koje gutaju klikove
    imh = imshow(I, [], 'Parent', ax);
    title(ax, 'Levi klik: tačka   |   Desni klik: kraj i fit linije');
    try, disableDefaultInteractivity(ax); end     % uifigure/uiaxes
    try, ax.Toolbar = []; end                     % ukloni toolbar ako postoji

    % Osiguraj da klikovi dopiru do handlera i preko slike
    set(ax, 'HitTest','on', 'PickableParts','all', 'ButtonDownFcn', @onClick);
    set(imh,'HitTest','on', 'PickableParts','all', 'ButtonDownFcn', @onClick);

    % Sakupljanje tačaka i skiciranje polilinije
    ptsX = [];  ptsY = [];
    hold(ax,'on');
    hPts  = plot(ax, nan, nan, 'yo', 'MarkerFaceColor','y', 'MarkerSize',5, 'PickableParts','none');
    hSkic = plot(ax, nan, nan, 'y-', 'LineWidth',1, 'PickableParts','none');
    hold(ax,'off');

    doneFlag = false;
    uiwait(fig);                                  % čekaj desni klik (uiresume ispod)

    % Očisti handlere (da ne ostanu zakačeni)
    if isvalid(ax), set(ax, 'ButtonDownFcn',[]); end
    if isgraphics(imh), set(imh,'ButtonDownFcn',[]); end

    if numel(ptsX) < 2
        error('Potrebno je označiti najmanje 2 tačke.');
    end

    % Fit prave y = m x + b
    p = polyfit(ptsX, ptsY, 1);
    slope = p(1); intercept = p(2);

    % Iscrtaj finalnu pravu
    xvals = linspace(1, size(I,2), 200);
    yvals = slope * xvals + intercept;
    hold(ax, 'on');
    plot(ax, xvals, yvals, 'r-', 'LineWidth', 2, 'PickableParts','none');
    hold(ax, 'off');

    %================= UGNJEŽDENE FUNKCIJE =================%

    function onClick(~, ev)
        % Izračunaj koordinate klika u koordinatama slike
        cp = ax.CurrentPoint;
        x  = cp(1,1);  y = cp(1,2);
        xl = xlim(ax); yl = ylim(ax);
        inside = x>=xl(1) && x<=xl(2) && y>=yl(1) && y<=yl(2);
        if ~inside, return; end

        % Odredi dugme (robustan fallback)
        btn = detectButton(ev, fig);

        if btn == 1
            % LEVI klik -> dodaj tačku i osveži skicu
            ptsX(end+1) = x; %#ok<AGROW>
            ptsY(end+1) = y; %#ok<AGROW>
            set(hPts,  'XData', ptsX, 'YData', ptsY);
            if numel(ptsX) >= 2
                set(hSkic, 'XData', ptsX, 'YData', ptsY);
            end
        elseif btn == 3
            % DESNI klik -> završetak
            doneFlag = true;
            uiresume(fig);
        end
    end
end

%------------------ POMOĆNA FUNKCIJA ------------------%
function b = detectButton(ev, fig)
% Pokušaj da pročitaš taster iz eventa (UIAxes/uifigure), sa fallback-om.
    b = 1;
    try
        % uifigure: matlab.ui.eventdata.ButtonDownData / WindowMousePressData
        if isobject(ev) && isprop(ev,'Button')
            b = ev.Button; return;
        end
        % klasična figura: SelectionType
        switch get(fig,'SelectionType')
            case 'normal', b = 1;
            case 'alt',    b = 3;
            case 'extend', b = 2;
            otherwise,     b = 1;
        end
    catch
        % ništa – ostavi default 1
    end
end
