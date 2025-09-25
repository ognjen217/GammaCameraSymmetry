function main_gui
% MAIN_GUI – Glavna MATLAB UI aplikacija za analizu simetrije slika.
% Koristi pomoćne funkcije iz foldera src i src/utils.
%
% Fajlovi koje koristi:
%   src/loadImages.m
%   src/defineAxis.m
%   src/reflectImageOverLine.m
%   src/compareSymmetry.m
%   src/showResults.m
%   src/utils/*.m  (getDefaultDirs, saveResults*, ensureDir, ...)
%
% Autor: (ti)

    % --- Osiguraj da je ceo src/ na putu (uklj. utils/) ---
    here = mfilename('fullpath');
    srcDir = fileparts(here);                         % .../src
    addpath(genpath(srcDir));                        % src + src/utils

    % ---------- UI ----------
    fig = uifigure('Name','Analiza simetrije slika','Position',[100 100 820 560]);

    btnLoad    = uibutton(fig, 'Text','Učitaj slike', 'Position',[20, 510, 120, 30], 'ButtonPushedFcn', @onLoad);
    btnDefine  = uibutton(fig, 'Text','Definiši osu',  'Position',[20, 470, 120, 30], 'ButtonPushedFcn', @onDefineAxis);
    btnProcess = uibutton(fig, 'Text','Pokreni analizu','Position',[20, 430, 120, 30], 'ButtonPushedFcn', @onProcess);

    uilabel(fig,'Text','Slike','Position',[20,400,120,20]);
    lstImages  = uilistbox(fig, 'Position',[20, 210, 120, 190], 'ValueChangedFcn', @onSelectImage);

    ax         = uiaxes(fig, 'Position',[170, 90, 620, 430]);
    title(ax,'Slika');
    axis(ax,'image'); axis(ax,'ij');

    tblResults = uitable(fig, 'Position',[170, 20, 620, 60], ...
        'ColumnName', {'Fajl','Nepoklapanja','Pomeraj','Odnos povrsina'}, ...
        'ColumnEditable', [false false false false], 'Data', {});

    % ---------- STATE ----------
    S = struct();
    S.handles = struct('fig',fig,'btnLoad',btnLoad,'btnDefine',btnDefine,'btnProcess',btnProcess, ...
                       'lst',lstImages,'ax',ax,'tbl',tblResults);

    % Dinamički podaci
    S.images       = {};      % {H x W double}
    S.imgNames     = {};      % {1 x N} imena fajlova
    S.currentIndex = [];      % trenutni indeks
    S.axisParams   = {};      % {1 x N} svaka ćelija [slope, intercept] ili []
    S.results      = {};      % {1 x N} rezultati (struct sa poljima)
    fig.UserData   = S;       % upiši state

    % =====================================================================
    % Callbacks
    % =====================================================================

    function onLoad(src,~)
        S = src.Parent.UserData;
        try
            [images, names] = loadImages();
            if isempty(images)
                return;
            end

            N = numel(images);
            S.images       = images;
            S.imgNames     = names;
            S.currentIndex = 1;
            S.axisParams   = cell(1,N);
            S.results      = cell(1,N);

            % UI lista i prikaz prve slike
            S.handles.lst.Items = names;
            S.handles.lst.Value = names{1};
            showCurrent(S);

            src.Parent.UserData = S;

        catch ME
            uialert(S.handles.fig, ME.message, 'Greška pri učitavanju');
        end
    end

    function onSelectImage(src,~)
        S = src.Parent.UserData;
        if isempty(S.imgNames), return; end
        idx = find(strcmp(S.handles.lst.Value, S.imgNames), 1, 'first');
        if isempty(idx), return; end
        S.currentIndex = idx;
        showCurrent(S);
        src.Parent.UserData = S;
    end

    function showCurrent(S)
        idx = S.currentIndex;
        I = S.images{idx};
        imshow(I, [], 'Parent', S.handles.ax);
        if isempty(S.axisParams{idx})
            ttl = sprintf('Slika: %s', S.imgNames{idx});
        else
            ttl = sprintf('Slika: %s (osa definisana)', S.imgNames{idx});
        end
        title(S.handles.ax, ttl);

        % Ako je osa već definisana za ovu sliku – nacrtaj je
        params = S.axisParams{idx};
        if ~isempty(params)
            slope = params(1); intercept = params(2);
            xvals = linspace(1, size(I,2), 100);
            yvals = slope * xvals + intercept;
            hold(S.handles.ax, 'on');
            plot(S.handles.ax, xvals, yvals, 'r-', 'LineWidth', 2);
            hold(S.handles.ax, 'off');
        end

        % Ako postoje rezultati – prikaži u tabeli
        if ~isempty(S.results{idx})
            r = S.results{idx};
            S.handles.tbl.Data = {S.imgNames{idx}, r.numMismatch, r.shift, r.areaRatio};
        else
            S.handles.tbl.Data = {S.imgNames{idx}, [], [], []};
        end
    end

    function onDefineAxis(src,~)
        S = src.Parent.UserData;
        try
            if isempty(S.currentIndex)
                uialert(S.handles.fig,'Nije izabrana slika.','Info'); return;
            end
            I = S.images{S.currentIndex};

            % Interaktivno biranje, vraća slope/intercept
            [slope, intercept] = defineAxis(I, S.handles.ax);
            S.axisParams{S.currentIndex} = [slope, intercept];

            % Osvježi prikaz
            showCurrent(S);
            src.Parent.UserData = S;

        catch ME
            uialert(S.handles.fig, ME.message, 'Greška pri definisanju ose');
        end
    end

    function onProcess(src,~)
        S = src.Parent.UserData;
        try
            if isempty(S.currentIndex)
                uialert(S.handles.fig,'Nije izabrana slika.','Info'); return;
            end
            params = S.axisParams{S.currentIndex};
            if isempty(params)
                uialert(S.handles.fig,'Osa nije definisana za ovu sliku.','Greška'); return;
            end

            I = S.images{S.currentIndex};
            slope = params(1); intercept = params(2);

            % 1) refleksija preko definisane ose
            Iref = reflectImageOverLine(I, slope, intercept);

            % 2) poređenje
            [numMismatch, shift, areaRatio, mismatchMask] = compareSymmetry(I, Iref);

            % 3) upiši rezultate u state i tabelu
            res = struct('numMismatch',numMismatch,'shift',shift,'areaRatio',areaRatio);
            S.results{S.currentIndex} = res;
            S.handles.tbl.Data = {S.imgNames{S.currentIndex}, numMismatch, shift, areaRatio};

            % 4) prikaži overlay
            showResults(I, mismatchMask, res, S.handles.ax, S.handles.tbl);

            % 5) Sačuvaj fajlove (CSV/MAT/PNG) u project_root/results
            dirs = getDefaultDirs();
            baseName = S.imgNames{S.currentIndex};
            saveResultsCSV(dirs.results, baseName, res);
            saveResultsMAT(dirs.results, baseName, res, struct('slope',slope,'intercept',intercept));
            saveMismatchOverlayPNG(dirs.figures, baseName, I, mismatchMask);
            % saveCurrentAxesPNG(dirs.figures, baseName, S.handles.ax); % opcionalno

            % Ažuriraj state
            src.Parent.UserData = S;

        catch ME
            uialert(S.handles.fig, ME.message, 'Greška pri analizi');
        end
    end

end
