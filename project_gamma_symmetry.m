function project_gamma_symmetry(mode, varargin)
% PROJECT_GAMMA_SYMMETRY – pokretanje GUI ili batch analize.
%   project_gamma_symmetry             % GUI
%   project_gamma_symmetry('gui')      % GUI
%   project_gamma_symmetry('batch')    % batch do 10 slika
%   project_gamma_symmetry('batch','N',20)

    if nargin<1 || isempty(mode), mode = 'gui'; end

    % lociraj project_root i dodaj /src na path
    thisFile    = mfilename('fullpath');
    projectRoot = fileparts(thisFile);
    addpath(fullfile(projectRoot,'src'));

    switch lower(mode)
        case 'gui'
            main_gui();  % pokreni UI
        case 'batch'
            p = inputParser; addParameter(p,'N',10,@(x)isnumeric(x)&&isscalar(x)&&x>0);
            parse(p,varargin{:}); N = p.Results.N;
            run_batch(projectRoot, N);
        otherwise
            error('Nepoznat režim: %s', mode);
    end
end

function run_batch(projectRoot, N)
    dataDir = fullfile(projectRoot,'data','original_images');
    if ~isfolder(dataDir), error('Nema foldera: %s', dataDir); end

    exts = {'.dcm','.png','.jpg','.jpeg','.tif','.tiff'};
    dd   = dir(dataDir);
    imgs = dd(arrayfun(@(f) ~f.isdir && any(strcmpi(exts,lower(fileparts(f.name,2)))), dd)); %#ok<FPARK> 

    % fallback za fileparts ekstenziju na starijem MATLAB-u:
    if isempty(imgs)
        imgs = dd(~[dd.isdir]);
        imgs = imgs(endsWith(lower({imgs.name}), exts));
    end

    if isempty(imgs), error('Nema slika u %s', dataDir); end
    imgs = imgs(1:min(N,numel(imgs)));

    % batch: za svaku sliku uzmi horizontalnu sredinu kao osu (y = H/2)
    for k = 1:numel(imgs)
        fpath = fullfile(imgs(k).folder, imgs(k).name);
        I = read_image_auto(fpath);
        H = size(I,1);
        slope = 0; intercept = H/2;

        Iref = reflectImageOverLine(I, slope, intercept);
        [numMismatch, shift, areaRatio, mismatchMask] = compareSymmetry(I, Iref); %#ok<ASGLU>

        fprintf('[OK] %s | mismatch=%d, shift=%.3f, areaRatio=%.3f\n', ...
            imgs(k).name, numMismatch, shift, areaRatio);
    end
    fprintf('Batch gotov.\n');
end

function I = read_image_auto(fpath)
    [~,~,ext] = fileparts(fpath);
    switch lower(ext)
        case '.dcm'
            I = dicomread(fpath);
            if ndims(I)>2, I = I(:,:,1); end
            I = mat2gray(double(I));   % normalizuj za prikaz/razliku
        otherwise
            Ir = imread(fpath);
            if ndims(Ir)==3, Ir = rgb2gray(Ir); end
            I = mat2gray(im2double(Ir));
    end
end
