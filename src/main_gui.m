function main_gui

    here   = mfilename('fullpath');
    srcDir = fileparts(here);
    addpath(genpath(srcDir));

    % ==================== LAYOUT ====================
    fig = uifigure('Name','Analiza simetrije slika','Position',[100 100 1180 640]);

    % Levo — kontrole i ulazi
    btnLoad    = uibutton(fig, 'Text','Učitaj slike',  'Position',[20, 585, 180, 30], 'ButtonPushedFcn', @onLoadDialog);
    btnDefine  = uibutton(fig, 'Text','Definiši osu',   'Position',[20, 545, 180, 30], 'ButtonPushedFcn', @onDefineAxis);
    btnProcess = uibutton(fig, 'Text','Pokreni analizu','Position',[20, 505, 180, 30], 'ButtonPushedFcn', @onProcess);

    uilabel(fig,'Text','Ulazne slike','Position',[20,475,190,20]);
    lstImages  = uilistbox(fig, 'Position',[20, 275, 120, 200], 'ValueChangedFcn', @onSelectImage);

    tglDCM   = uibutton(fig,'state','Text','.dcm',     'Position',[20, 240, 60, 28], 'ValueChangedFcn', @onFilterChange);
    tglRAST  = uibutton(fig,'state','Text','.png/jpg', 'Position',[90, 240, 60, 28], 'ValueChangedFcn', @onFilterChange);
    tglDCM.Value  = true;
    tglRAST.Value = true;

    % Sredina — glavna osa + tabela + dugmad
    ax = uiaxes(fig, 'Position',[170, 110, 780, 470]);
    title(ax,'Slika'); axis(ax,'image'); axis(ax,'ij');
    try disableDefaultInteractivity(ax); catch 
    end

    btnSaveView = uibutton(fig,'Text','Sačuvaj prikaz','Position',[850, 585, 110, 30], 'ButtonPushedFcn', @onSaveView);
    btnInfo     = uibutton(fig,'Text','Info','Position',[900, 550, 60, 30], 'ButtonPushedFcn', @onInfo);
    
    btnAuto     = uibutton(fig,'Text','AUTOMATSKA DETEKCIJA', 'Position',[20, 200, 190, 30], 'ButtonPushedFcn', @onAutoDetect);

    tblResults = uitable(fig, 'Position',[170, 20, 780, 70], ...
        'ColumnName', {'Fajl','% poklapanja','% nepoklapanja','Simetrija','Pomeraj (px)','Odnos površina'}, ...
        'ColumnEditable', [false false false false false false], 'Data', {});

    % Desno — lista .png rezultata (auto-popunjavanje već na startu)
    uilabel(fig,'Text','Rezultati (.png)','Position',[970,585,190,20]);
    lstOutputs = uilistbox(fig, 'Position',[970, 275, 190, 330], 'ValueChangedFcn', @onSelectOutput);

    % ==================== STATE ====================
    S = struct();
    S.handles = struct('fig',fig,'btnLoad',btnLoad,'btnDefine',btnDefine,'btnProcess',btnProcess, ...
                       'lst',lstImages,'ax',ax,'tbl',tblResults,'tglDCM',tglDCM,'tglRAST',tglRAST, ...
                       'lstOut',lstOutputs,'btnSaveView',btnSaveView,'btnInfo',btnInfo, ...
                       'btnAuto',btnAuto);

    S.files        = [];
    S.filteredIdx  = [];
    S.images       = containers.Map('KeyType','double','ValueType','any');
    S.axisParams   = containers.Map('KeyType','double','ValueType','any');
    S.results      = containers.Map('KeyType','double','ValueType','any');
    S.metrics      = containers.Map('KeyType','double','ValueType','any');
    S.currentIndex = [];
    S.symThresh    = 60;   % prag za odluku o simetriji po % poklapanja (možeš menjati)
    fig.UserData = S;

    populateFromDefaultDir(fig);
    refreshOutputsList();

    % ==================== FUNKCIJE ====================

    function populateFromDefaultDir(figHandle)
        S = figHandle.UserData;
        dirs = getDefaultDirs();
        srcFolder = fullfile(dirs.data, 'original_images');
        if ~exist(srcFolder,'dir')
            srcFolder = fullfile(fileparts(srcDir), 'data', 'original_images');
        end
        assert(exist(srcFolder,'dir')==7, sprintf('Ne postoji folder: %s', srcFolder));

        pats = {'*.dcm','*.DCM','*.png','*.PNG','*.jpg','*.JPG','*.jpeg','*.JPEG','*.bmp','*.BMP','*.tif','*.TIF','*.tiff','*.TIFF'};
        files = [];
        for i = 1:numel(pats), files = [files; dir(fullfile(srcFolder, pats{i}))]; end %#ok<AGROW>
        for k=1:numel(files)
            [~,~,e] = fileparts(files(k).name);
            files(k).ext  = lower(e);
            files(k).path = fullfile(files(k).folder, files(k).name);
        end
        if ~isempty(files)
            [~,ia] = unique({files.path}, 'stable'); files = files(ia);
            [~,ord] = sort({files.name}); files = files(ord);
        end

        % reset keševa
        S.files        = files;
        S.images       = containers.Map('KeyType','double','ValueType','any');
        S.axisParams   = containers.Map('KeyType','double','ValueType','any');
        S.results      = containers.Map('KeyType','double','ValueType','any');
        S.metrics      = containers.Map('KeyType','double','ValueType','any');
        figHandle.UserData = S;

        applyFilterAndRefreshList();
    end

    function onLoadDialog(src,~)
        S = src.Parent.UserData;
        [fn,fp] = uigetfile({ ...
            '*.dcm','DICOM (*.dcm)'; ...
            '*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff','Raster slike'}, ...
            'Izaberi slike (više dozvoljeno)', 'MultiSelect','on');
        if isequal(fn,0), return; end
        if ischar(fn), fn={fn}; end

        existing = string(arrayfun(@(r) r.path, S.files, 'UniformOutput', false));
        for i=1:numel(fn)
            p = fullfile(fp,fn{i});
            if any(existing == string(p)), continue; end
            rec = dir(p);
            [~,~,e] = fileparts(rec.name);
            rec.ext  = lower(e);
            rec.path = p;
            S.files = [S.files; rec];
        end

        src.Parent.UserData = S;
        applyFilterAndRefreshList();
    end

    function onFilterChange(~,~), applyFilterAndRefreshList(); end

    function applyFilterAndRefreshList()
        S = fig.UserData;
        if isempty(S.files)
            S.filteredIdx=[]; S.handles.lst.Items={}; fig.UserData=S; return;
        end

        showDCM  = logical(S.handles.tglDCM.Value);
        showRAST = logical(S.handles.tglRAST.Value);

        if ~showDCM && ~showRAST
            idx = [];
        else
            idx = 1:numel(S.files);
            if xor(showDCM, showRAST)
                if showDCM
                    mask = ismember({S.files.ext},{'.dcm'});
                else
                    mask = ismember({S.files.ext},{'.png','.jpg','.jpeg','.bmp','.tif','.tiff'});
                end
                idx = idx(mask);
            end
        end

        S.filteredIdx = idx;
        items = arrayfun(@(k) S.files(k).name, idx, 'UniformOutput', false);
        if isempty(items), items = {'<nema fajlova>'}; end
        S.handles.lst.Items = items;

        if ~isempty(idx)
            S.handles.lst.Value = items{1};
            S.currentIndex = idx(1);
            fig.UserData = S;
            showCurrent();
        else
            S.currentIndex = [];
            fig.UserData = S;
            cla(S.handles.ax); title(S.handles.ax,'Slika');
            S.handles.tbl.Data = {};
        end
    end

    function onSelectImage(src,~)
        S = src.Parent.UserData;
        if isempty(S.filteredIdx)||isempty(S.files), return; end
        items=S.handles.lst.Items; pos=find(strcmp(items,S.handles.lst.Value),1,'first');
        if isempty(pos), return; end
        S.currentIndex = S.filteredIdx(pos);
        src.Parent.UserData = S;
        showCurrent();
    end

    function I = getImageAt(idx)
        % ROBUSNO učitavanje (DICOM potpuno podržan)
        S = fig.UserData;
        if isKey(S.images, idx)
            I = S.images(idx); return;
        end
        rec = S.files(idx);
        switch rec.ext
            case '.dcm'
                try
                    info = dicominfo(rec.path);
                    I = dicomread(info);
                    I = double(I);
                    if isfield(info,'RescaleSlope'),     I = I * double(info.RescaleSlope);   end
                    if isfield(info,'RescaleIntercept'), I = I + double(info.RescaleIntercept); end
                    I = I - min(I(:)); mx = max(I(:)); if mx>0, I = I/mx; end
                    if isfield(info,'PhotometricInterpretation') && strcmpi(info.PhotometricInterpretation,'MONOCHROME1')
                        I = 1 - I;
                    end
                    if ndims(I)==3 && size(I,3)~=3, I = I(:,:,round(end/2)); end
                    if ndims(I)==4, I = squeeze(I(:,:,:,round(end/2))); end
                catch
                    I = im2double(readImageAny(rec.path));
                end
            otherwise
                I = im2double(readImageAny(rec.path));
        end
        if ndims(I)==3, I = rgb2gray(I); end
        S.images(idx) = I; fig.UserData = S;
    end

    function showCurrent()
        S = fig.UserData; if isempty(S.currentIndex), return; end
        I = getImageAt(S.currentIndex);
        imshow(I, [], 'Parent', S.handles.ax);
        axis(S.handles.ax,'ij'); axis(S.handles.ax,'image'); hold(S.handles.ax,'on');

        % isečena osa (ako postoji)
        if isKey(S.axisParams, S.currentIndex)
            p = S.axisParams(S.currentIndex);
            [xseg,yseg] = clipLineToImage(p(1), p(2), size(I));
            if ~isempty(xseg)
                plot(S.handles.ax, xseg, yseg, 'r-', 'LineWidth', 2, 'PickableParts','none');
            end
            ttl = sprintf('Slika: %s (osa definisana)', S.files(S.currentIndex).name);
        else
            ttl = sprintf('Slika: %s', S.files(S.currentIndex).name);
        end
        hold(S.handles.ax,'off');
        title(S.handles.ax, ttl, 'Interpreter','none');

        % tabela
        if isKey(S.results, S.currentIndex)
            r = S.results(S.currentIndex);
            symTxt = tern(r.isSymmetric,'DA','NE');
            S.handles.tbl.Data = {S.files(S.currentIndex).name, r.matchPct, r.mismatchPct, symTxt, r.shift, r.areaRatio};
        else
            S.handles.tbl.Data = {S.files(S.currentIndex).name, [], [], [], [], []};
        end
    end

    function onDefineAxis(src,~)
        S = src.Parent.UserData;
        if isempty(S.currentIndex), uialert(S.handles.fig,'Nije izabrana slika.','Info'); return; end
        I = getImageAt(S.currentIndex);
        [slope, intercept] = defineAxis(I, S.handles.ax, S.handles.fig);
        S.axisParams(S.currentIndex)=[slope,intercept]; src.Parent.UserData=S; showCurrent();
    end

    function onProcess(src,~)
            S = src.Parent.UserData;
            if isempty(S.currentIndex), uialert(S.handles.fig,'Nije izabrana slika.','Info'); return; end
            if ~isKey(S.axisParams, S.currentIndex), uialert(S.handles.fig,'Osa nije definisana.','Greška'); return; end
    
            I = getImageAt(S.currentIndex);
            p = S.axisParams(S.currentIndex); slope=p(1); intercept=p(2);
            Iref = reflectImageOverLine(I, slope, intercept);
    
            [numMismatch, shift, areaRatio, mismatchMask, metrics] = compareSymmetry(I, Iref);
    
            % ---------- NOVO: robustni procenti i odluka ----------
            % 1) foreground-only procenat (ignoriše pozadinu)
            fg = computeForegroundMask(I, Iref);
            numFG           = max(1, nnz(fg));
            numMismatchFG   = nnz(mismatchMask & fg);
            mismatchPct_fg  = 100 * double(numMismatchFG) / double(numFG);
            matchPct_fg     = 100 - mismatchPct_fg;
    
            % 2) ako compareSymmetry daje pouzdaniju metriku, uzmi nju
            match_frac = getMetric(metrics, {'match_frac','matchFrac','match_fraction'}, NaN);
            if ~isnan(match_frac), matchPct = 100*double(match_frac);
            else,                  matchPct = matchPct_fg;
            end
            mismatchPct = 100 - matchPct;
    
            % 3) kombinovana odluka (više je bolje)
            ssim_val = getMetric(metrics, {'SSIM','ssim'}, NaN);
            dice_val = getMetric(metrics, {'dice_edges','dice','edge_dice'}, NaN);
            ssim_ok  = ~isnan(ssim_val) && ssim_val >= 0.75;
            dice_ok  = ~isnan(dice_val) && dice_val >= 0.50;
            frac_ok  = matchPct >= S.symThresh;     % npr. 60%
            isSym    = ssim_ok || dice_ok || frac_ok;
            % -------------------------------------------------------
    
            % zapamti
            res = struct('numMismatch',numMismatch, ...
                         'mismatchPct',mismatchPct, ...
                         'matchPct',matchPct, ...
                         'isSymmetric',isSym, ...
                         'shift',shift,'areaRatio',areaRatio);
            S.results(S.currentIndex) = res;
            S.metrics(S.currentIndex) = metrics;
    
            % prikaži + osa isečena
            showResults(I, mismatchMask, [], S.handles.ax, [], [], metrics);
            hold(S.handles.ax,'on');
            [xseg,yseg] = clipLineToImage(slope,intercept,size(I));
            if ~isempty(xseg)
                plot(S.handles.ax, xseg, yseg, 'r-', 'LineWidth', 2, 'PickableParts','none');
            end
            hold(S.handles.ax,'off');
    
            % snimanje na disk (standardni rezultati)
            dirs = getDefaultDirs();
            baseName = S.files(S.currentIndex).name;
            saveResultsCSV(dirs.results, baseName, res);
            extras = struct('slope',slope,'intercept',intercept,'metrics',metrics, ...
                            'imageSize',size(I),'file',S.files(S.currentIndex).path);
            saveResultsMAT(dirs.results, baseName, res, extras);
            try saveHeatmapPNG(dirs.results, baseName, abs(I-Iref)); 
            catch, ...
            end
            try E1=edge(I,'canny'); E2=edge(Iref,'canny'); catch, E1=edge(I,'sobel'); E2=edge(Iref,'sobel'); end
            saveEdgesOverlayPNG(dirs.results, baseName, I, E1, E2);
    
            src.Parent.UserData = S;
    
            % ODMAH osveži desnu listu i tabelu
            refreshOutputsList(baseName);
            symTxt = tern(isSym,'DA','NE');
            S.handles.tbl.Data = {S.files(S.currentIndex).name, matchPct, mismatchPct, symTxt, shift, areaRatio};
        end
    
        function onSaveView(~,~)
            % Snimi ono što je trenutno prikazano u glavnoj osi (sa timestamp-om)
            S = fig.UserData;
            dirs = getDefaultDirs();
            if ~exist(dirs.results,'dir'), mkdir(dirs.results); end
            if isempty(S.currentIndex)
                base = 'no_input';
            else
                base = stripExt(S.files(S.currentIndex).name);
            end
            stamp = datestr(now,'yyyymmdd_HHMMSS');
            fn = fullfile(dirs.results, sprintf('axes_%s_%s.png', base, stamp));
            try
                saveCurrentAxesPNG(dirs.results, sprintf('%s_%s.png', base, stamp), S.handles.ax);
                uialert(S.handles.fig, sprintf('Sačuvano:\n%s', fn), 'OK');
            catch ME
                % fallback ako util ne postoji
                try
                    frame = getframe(S.handles.ax);
                    imwrite(frame.cdata, fn);
                    uialert(S.handles.fig, sprintf('Sačuvano:\n%s', fn), 'OK');
                catch
                    uialert(S.handles.fig, ME.message, 'Greška pri snimanju');
                end
            end
            refreshOutputsList(); % osveži listu nakon snimanja
        end
    
        function onInfo(~,~)
            % Kratko objašnjenje metrika i praga
            S = fig.UserData;
            msg = sprintf([ ...
                'Objašnjenje metrika:\n' ...
                '• %% poklapanja = 100 − %% nepoklapanja (računato nad foreground-om slike).\n' ...
                '• Foreground se detektuje kombinacijom Otsu praga i relativnog praga (ignoriše pozadinu).\n' ...
                '• Ako su dostupne napredne metrike (npr. match_frac, SSIM, Dice), one se koriste za procenu.\n' ...
                '• Simetrija = DA ako je bilo koji od uslova ispunjen:\n' ...
                '    – match_frac ≥ %d%%  (trenutni prag)\n' ...
                '    – SSIM ≥ 0.75\n' ...
                '    – Dice (edges) ≥ 0.50\n' ...
                '• Pomeraj (px) i Odnos površina preuzeti su iz compareSymmetry.\n'], S.symThresh);
            uialert(S.handles.fig, msg, 'Info o metrikama');
        end
    
    
        function onAutoDetect(src, ~)
        S = src.Parent.UserData;
        if isempty(S.currentIndex)
            uialert(S.handles.fig,'Nije izabrana slika.','Info'); return;
        end
    
        % privremeno onemogući glavne kontrole (opciono, ali progress dlg je već modal)
        ctrls = [S.handles.btnLoad S.handles.btnDefine S.handles.btnProcess ...
                 S.handles.btnSaveView S.handles.btnInfo S.handles.btnAuto ...
                 S.handles.tglDCM S.handles.tglRAST S.handles.lst S.handles.lstOut];
        set(ctrls, 'Enable','off');
    
        try
            I = getImageAt(S.currentIndex);  % tvoja postojeća funkcija u main_gui
            [m, b, ~] = autoDetect(I, ...
                'ax',  S.handles.ax, ...
                'fig', S.handles.fig, ...
                'thresholdPct', S.symThresh, ...
                'useScore', true);
    
            % Sačuvaj osu u state i osveži prikaz
            S.axisParams(S.currentIndex) = [m,b];
            src.Parent.UserData = S;
            showCurrent();  % već boji osu na glavnoj osi
    
        catch ME
            uialert(S.handles.fig, ME.message, 'Greška (auto detekcija)');
        end
    
        % re-enable
        try set(ctrls,'Enable','on'); catch, end
    end


    % --------- Desni preglednik izlaza ---------
    function refreshOutputsList(selectBase)
        if nargin<1, selectBase=''; end
        S = fig.UserData;
        dirs = getDefaultDirs();
        pngs = dir(fullfile(dirs.results, '*.png'));
        [~,ord] = sort([pngs.datenum],'descend'); pngs = pngs(ord);
        items = arrayfun(@(d) d.name, pngs, 'UniformOutput', false);
        if isempty(items), items = {'<nema .png rezultata>'}; end
        S.handles.lstOut.Items = items;

        if ~isempty(selectBase) && ~isempty(pngs)
            base = stripExt(selectBase);
            ix = find(contains(items, base), 1, 'first');
            if ~isempty(ix), S.handles.lstOut.Value = items{ix}; end
        end
        fig.UserData = S;
    end

    function onSelectOutput(src,~)
        S = src.Parent.UserData;
        if isempty(src.Items) || strcmp(src.Items{1},'<nema .png rezultata>'), return; end
        dirs = getDefaultDirs();
        fpath = fullfile(dirs.results, src.Value);
        if exist(fpath,'file')
            try
                I = imread(fpath);
                imshow(I, 'Parent', S.handles.ax);
                axis(S.handles.ax,'ij'); axis(S.handles.ax,'image');
                title(S.handles.ax, sprintf('REZULTAT: %s', src.Value), 'Interpreter','none');
            catch ME
                uialert(S.handles.fig, ME.message, 'Greška pri učitavanju rezultata');
            end
        end
    end

    % --------- Geometrija: iseći pravu na okvir slike ---------
    function [xseg,yseg] = clipLineToImage(slope, intercept, imgSize)
        H = imgSize(1); W = imgSize(2);
        m = slope; b = intercept;

        pts = []; % [x y]
        % preseci sa x = 1 i x = W
        y1 = m*1 + b;   if y1>=1 && y1<=H, pts(end+1,:) = [1, y1]; end 
        yW = m*W + b;   if yW>=1 && yW<=H, pts(end+1,:) = [W, yW]; end 
        % preseci sa y = 1 i y = H  (ako |m|>0)
        if abs(m) > eps
            x1 = (1 - b)/m;  if x1>=1 && x1<=W, pts(end+1,:) = [x1, 1]; end 
            xH = (H - b)/m;  if xH>=1 && xH<=W, pts(end+1,:) = [xH, H]; end 
        else
            % horizontalna linija
            y = b; if y>=1 && y<=H, pts = [1,y; W,y]; end
        end

        if isempty(pts)
            xseg = []; yseg = []; return;
        end
        % jedinstvene i najviše dve najudaljenije
        pts = round(pts,6);
        [~, ia] = unique(pts,'rows','stable'); pts = pts(ia,:);
        if size(pts,1) > 2
            bestd = -inf; pair=[1 2];
            for i=1:size(pts,1)
                for j=i+1:size(pts,1)
                    d = hypot(pts(i,1)-pts(j,1), pts(i,2)-pts(j,2));
                    if d>bestd, bestd=d; pair=[i j]; end
                end
            end
            pts = pts(pair,:);
        end
        if size(pts,1) < 2
            xseg = [1 W]; yseg = [m*1+b, m*W+b];
        else
            xseg = pts(:,1)'; yseg = pts(:,2)';
        end
    end

    % --------- HELPERI ---------
    function y = tern(cond,a,b)
        if cond, y=a; else, y=b; end
    end

    function fg = computeForegroundMask(I, Iref)
        % robustna maska foreground-a (ignoriše veliku pozadinu)
        if ~isfloat(I),    I    = im2double(I);    end
        if ~isfloat(Iref), Iref = im2double(Iref); end
        I   = mat2gray(I);    Iref = mat2gray(Iref);

        t1 = graythresh(I);
        t2 = graythresh(Iref);
        t  = max([t1, t2, 0.05]);  % donji prag

        fg = (I >= t) | (Iref >= t);
        fg = bwareaopen(fg, max(30, round(numel(I)*0.0005)));
        fg = imfill(fg, 'holes');
    end

    function val = getMetric(M, names, defaultVal)
        % pokušaj više naziva polja (robustno na različita imena)
        val = defaultVal;
        if ~isstruct(M), return; end
        for k=1:numel(names)
            n = names{k};
            if isfield(M,n) && ~isempty(M.(n))
                val = double(M.(n));
                return;
            end
        end
    end
end
