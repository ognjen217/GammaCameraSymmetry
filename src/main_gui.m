function main_gui

    here   = mfilename('fullpath');
    srcDir = fileparts(here);
    addpath(genpath(srcDir));

    fig = uifigure('Name','Analiza simetrije slika','Position',[100 100 840 600]);

    btnLoad    = uibutton(fig, 'Text','Učitaj slike',  'Position',[20, 545, 120, 30], 'ButtonPushedFcn', @onLoadDialog);
    btnDefine  = uibutton(fig, 'Text','Definiši osu',   'Position',[20, 505, 120, 30], 'ButtonPushedFcn', @onDefineAxis);
    btnProcess = uibutton(fig, 'Text','Pokreni analizu','Position',[20, 465, 120, 30], 'ButtonPushedFcn', @onProcess);

    uilabel(fig,'Text','Slike','Position',[20,435,120,20]);
    lstImages  = uilistbox(fig, 'Position',[20, 235, 120, 200], 'ValueChangedFcn', @onSelectImage);

    tglDCM   = uibutton(fig,'state','Text','.dcm',     'Position',[20, 200, 55, 28], 'ValueChangedFcn', @onFilterChange);
    tglRAST  = uibutton(fig,'state','Text','.png/jpg', 'Position',[85, 200, 55, 28], 'ValueChangedFcn', @onFilterChange);

    ax         = uiaxes(fig, 'Position',[170, 110, 650, 470]); title(ax,'Slika'); axis(ax,'image'); axis(ax,'ij');
    try disableDefaultInteractivity(ax); end
    tblResults = uitable(fig, 'Position',[170, 20, 650, 70], ...
        'ColumnName', {'Fajl','Nepoklapanja','Pomeraj','Odnos povrsina'}, ...
        'ColumnEditable', [false false false false], 'Data', {});

    S = struct();
    S.handles = struct('fig',fig,'btnLoad',btnLoad,'btnDefine',btnDefine,'btnProcess',btnProcess, ...
                       'lst',lstImages,'ax',ax,'tbl',tblResults,'tglDCM',tglDCM,'tglRAST',tglRAST);
    S.files        = [];
    S.filteredIdx  = [];
    S.images       = containers.Map('KeyType','double','ValueType','any');
    S.axisParams   = containers.Map('KeyType','double','ValueType','any');
    S.results      = containers.Map('KeyType','double','ValueType','any');       
    S.metrics      = containers.Map('KeyType','double','ValueType','any');
    S.currentIndex = [];
    fig.UserData = S;

    populateFromDefaultDir(fig);

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
        S.files = files;
        S.images       = containers.Map('KeyType','double','ValueType','any');
        S.axisParams   = containers.Map('KeyType','double','ValueType','any');
        S.results      = containers.Map('KeyType','double','ValueType','any');
        S.metrics      = containers.Map('KeyType','double','ValueType','any');
        S.currentIndex = [];
        S.handles.tglDCM.Value = false; S.handles.tglRAST.Value = false;
        figHandle.UserData = S;
        applyFilterAndRefreshList();
    end

    function onLoadDialog(src,~)
        S = src.Parent.UserData;
        [imgs, names] = loadImages();
        if isempty(imgs), return; end
        existing = string(arrayfun(@(r) r.path, S.files, 'UniformOutput', false));
        for i = 1:numel(names)
            p = string(names{i}); if ~isfile(p), continue; end
            if any(existing == p), continue; end
            [folder, base, ext] = fileparts(p);
            rec = struct('name',[base ext],'folder',folder,'date','','bytes',[],'isdir',false,'datenum',[], ...
                         'ext',lower(ext),'path',char(p));
            S.files = [S.files; rec]; 
        end
        src.Parent.UserData = S; applyFilterAndRefreshList();
    end

    function onFilterChange(~,~), applyFilterAndRefreshList(); end

    function applyFilterAndRefreshList()
        S = fig.UserData;
        if isempty(S.files), S.filteredIdx=[]; S.handles.lst.Items={}; fig.UserData=S; return; end
        showDCM=S.handles.tglDCM.Value; showRAST=S.handles.tglRAST.Value;
        idx = 1:numel(S.files);
        if xor(showDCM, showRAST)
            if showDCM, mask=ismember({S.files.ext},{'.dcm'});
            else, mask=ismember({S.files.ext},{'.png','.jpg','.jpeg','.bmp','.tif','.tiff'});
            end
            idx = idx(mask);
        end
        S.filteredIdx = idx; items = arrayfun(@(k) S.files(k).name, idx, 'UniformOutput', false);
        if isempty(items), items = {'<nema fajlova>'}; end
        S.handles.lst.Items = items;
        if ~isempty(idx)
            S.handles.lst.Value = items{1}; S.currentIndex = idx(1); fig.UserData=S; showCurrent();
        else
            S.currentIndex = []; fig.UserData=S; cla(S.handles.ax); title(S.handles.ax,'Slika'); S.handles.tbl.Data={};
        end
    end

    function onSelectImage(src,~)
        S = src.Parent.UserData;
        if isempty(S.filteredIdx)||isempty(S.files), return; end
        items=S.handles.lst.Items; pos=find(strcmp(items,S.handles.lst.Value),1,'first');
        if isempty(pos), return; end
        S.currentIndex = S.filteredIdx(pos); src.Parent.UserData=S; showCurrent();
    end

    function I = getImageAt(idx)
        S = fig.UserData;
        if isKey(S.images, idx), I = S.images(idx); return; end
        fpath = S.files(idx).path; I = readImageAny(fpath); S.images(idx)=I; fig.UserData=S;
    end

    function showCurrent()
        S = fig.UserData; if isempty(S.currentIndex), return; end
        I = getImageAt(S.currentIndex); imshow(I, [], 'Parent', S.handles.ax);
        if isKey(S.axisParams, S.currentIndex)
            p=S.axisParams(S.currentIndex); slope=p(1); intercept=p(2);
            xvals=linspace(1,size(I,2),100); yvals=slope*xvals+intercept;
            hold(S.handles.ax,'on'); plot(S.handles.ax,xvals,yvals,'r-','LineWidth',2); hold(S.handles.ax,'off');
            ttl=sprintf('Slika: %s (osa definisana)', S.files(S.currentIndex).name);
        else
            ttl=sprintf('Slika: %s', S.files(S.currentIndex).name);
        end
        title(S.handles.ax, ttl);
        if isKey(S.results, S.currentIndex)
            r=S.results(S.currentIndex);
            S.handles.tbl.Data={S.files(S.currentIndex).name, r.numMismatch, r.shift, r.areaRatio};
        else
            S.handles.tbl.Data={S.files(S.currentIndex).name, [], [], []};
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

        if isfield(metrics,'match_mask') && ~isempty(metrics.match_mask)
            matchMask = metrics.match_mask;
        else
            matchMask = ~mismatchMask & (I > 0.05 | Iref > 0.05);
        end

        res = struct('numMismatch',numMismatch,'shift',shift,'areaRatio',areaRatio);
        S.results(S.currentIndex) = res;
        S.metrics(S.currentIndex) = metrics;
        S.handles.tbl.Data = {S.files(S.currentIndex).name, numMismatch, shift, areaRatio};

        showResults(I, mismatchMask, res, S.handles.ax, S.handles.tbl, matchMask, metrics);

        dirs = getDefaultDirs();
        baseName = S.files(S.currentIndex).name;
        saveResultsCSV(dirs.results, baseName, res);
        extras = struct('slope',slope,'intercept',intercept,'metrics',metrics, ...
                        'imageSize',size(I),'file',S.files(S.currentIndex).path);
        saveResultsMAT(dirs.results, baseName, res, extras);
        saveHeatmapPNG(dirs.results, baseName, abs(I-Iref));
        try E1=edge(I,'canny'); E2=edge(Iref,'canny'); catch, E1=edge(I,'sobel'); E2=edge(Iref,'sobel'); end
        saveEdgesOverlayPNG(dirs.results, baseName, I, E1, E2);

        src.Parent.UserData = S;
    end
end
