function main_gui
% MAIN_GUI – Glavna MATLAB UI aplikacija za analizu simetrije slika.
% Ovaj fajl koristi sledeće pomoćne funkcije (kao odvojene .m fajlove u /src):
%   loadImages.m
%   defineAxis.m
%   reflectImageOverLine.m
%   compareSymmetry.m
%   showResults.m

    % ---------- UI ----------
    fig = uifigure('Name','Analiza simetrije slika','Position',[100 100 800 520]);

    btnLoad      = uibutton(fig, 'Text','Učitaj slike', 'Position',[20, 470, 120, 30], 'ButtonPushedFcn', @onLoad);
    btnDefine    = uibutton(fig, 'Text','Definiši osu',  'Position',[20, 430, 120, 30], 'ButtonPushedFcn', @onDefineAxis);
    btnProcess   = uibutton(fig, 'Text','Pokreni analizu','Position',[20, 390, 120, 30], 'ButtonPushedFcn', @onProcess);

    uilabel(fig,'Text','Slike','Position',[20,360,120,20]);
    lstImages    = uilistbox(fig, 'Position',[20, 180, 120, 180], 'ValueChangedFcn', @onSelectImage);

    ax           = uiaxes(fig, 'Position',[170, 80, 600, 420]);
    title(ax,'Slika');
    axis(ax,'image'); axis(ax,'ij');

    tblResults   = uitable(fig, 'Position',[170, 20, 600, 50], ...
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

            % UI osveženje liste
            S.handles.lst.Items = names;
            S.handles.lst.Value = names{1};

            % Prvi prikaz
            I = S.images{1};
            imshow(I, [], 'Parent', S.handles.ax);
            title(S.handles.ax, sprintf('Slika: %s', S.imgNames{1}));

            % Tabela prazna/početna
            S.handles.tbl.Data = {S.imgNames{1}, [], [], []};

            src.Parent.UserData = S;
        catch ME
            uialert(S.handles.fig, ME.message, 'Greška pri učitavanju');
        end
    end

    function onSelectImage(src,~)
        fig = src.Parent;
        S = fig.UserData;
        if isempty(S.imgNames)
            return;
        end
        selName = src.Value;
        idx = find(strcmp(S.imgNames, selName), 1);
        if isempty(idx)
            return;
        end
        S.currentIndex = idx;

        % Prikaz slike
        I = S.images{idx};
        imshow(I, [], 'Parent', S.handles.ax);
        title(S.handles.ax, sprintf('Slika: %s', S.imgNames{idx}));

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

        % Ako postoje rezultati – prikaži ih
        if ~isempty(S.results{idx})
            r = S.results{idx};
            S.handles.tbl.Data = {S.imgNames{idx}, r.numMismatch, r.shift, r.areaRatio};
        else
            S.handles.tbl.Data = {S.imgNames{idx}, [], [], []};
        end

        fig.UserData = S;
    end

    function onDefineAxis(src,~)
        S = src.Parent.UserData;
        try
            if isempty(S.currentIndex)
                uialert(S.handles.fig,'Nije izabrana slika.','Info'); return;
            end
            I = S.images{S.currentIndex};
            [slope, intercept] = defineAxis(I, S.handles.ax);
            S.axisParams{S.currentIndex} = [slope, intercept];

            % Ažuriraj prikaz naslova
            title(S.handles.ax, sprintf('Slika: %s (osa definisana)', S.imgNames{S.currentIndex}));

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

            % 1) Refleksija
            Iref = reflectImageOverLine(I, slope, intercept);

            % 2) Poređenje
            [numMismatch, shift, areaRatio, mismatchMask] = compareSymmetry(I, Iref);
            res = struct('numMismatch', numMismatch, 'shift', shift, 'areaRatio', areaRatio);

            % 3) Prikaz i tabela
            showResults(I, mismatchMask, res, S.handles.ax, S.handles.tbl);
            
            dirs = getDefaultDirs();
            baseName = S.imgNames{S.currentIndex};
            saveResultsCSV(dirs.results, baseName, res);
            saveResultsMAT(dirs.results, baseName, res, struct('slope',slope,'intercept',intercept));
            saveMismatchOverlayPNG(dirs.figures, baseName, I, mismatchMask);

            % 4) Sačuvaj rezultate
            S.results{S.currentIndex} = res;

            % 5) Sačuvaj fajlove
            dirs = getDefaultDirs();
            baseName = S.imgNames{S.currentIndex};
            saveResultsCSV(dirs.results, baseName, res);
            saveResultsMAT(dirs.results, baseName, res, struct('slope',slope,'intercept',intercept));
            saveMismatchOverlayPNG(dirs.figures, baseName, I, mismatchMask);
            % opciono, ako želiš i “screenshot” trenutnog prikaza:
            % saveCurrentAxesPNG(dirs.figures, baseName, S.handles.ax);

            % Ažuriraj state
            src.Parent.UserData = S;

        catch ME
            uialert(S.handles.fig, ME.message, 'Greška pri analizi');
        end
    end

end
