function project_gamma_symmetry(mode, varargin)

    if nargin<1 || isempty(mode), mode = 'gui'; end

    thisFile    = mfilename('fullpath');
    projectRoot = fileparts(thisFile);
    addpath(genpath(fullfile(projectRoot,'src')));

    switch lower(mode)
        case 'gui'
            main_gui();

        case 'batch'
            p = inputParser;
            addParameter(p,'N',10,@(x)isnumeric(x) && isscalar(x) && x>0);
            parse(p,varargin{:});
            N = p.Results.N;

            dirs = getDefaultDirs();

            imgs = dir(fullfile(dirs.data, 'original_images', '*'));
            imgs = imgs(~[imgs.isdir]);
            imgs = imgs(1:min(N,numel(imgs)));

            for k = 1:numel(imgs)
                f = fullfile(imgs(k).folder, imgs(k).name);
                I = read_image_auto(f);
                % jednostavna osa: sredina slike, vertikalna
                m = 0; b = size(I,1)/2;
                Iref = reflectImageOverLine(I,m,b);
                [nm,sh,ar,mask] = compareSymmetry(I,Iref);
                res = struct('numMismatch',nm,'shift',sh,'areaRatio',ar);
                saveResultsCSV(dirs.results, imgs(k).name, res);
                saveMismatchOverlayPNG(dirs.figures, imgs(k).name, I, mask);
            end

        otherwise
            error('Nepoznat režim: %s', mode);
    end
end

function I = read_image_auto(fpath)
    [~,~,ext] = fileparts(fpath);
    switch lower(ext)
        case '.dcm'
            info = dicominfo(fpath);
            I = dicomread(info);
            if ndims(I) == 3 && size(I,3) ~= 3
                k  = round(size(I,3)/2);
                I = I(:,:,k);
            elseif ndims(I) == 4
                k  = round(size(I,4)/2);
                I = I(:,:,:,k);
                if size(I,3) ~= 3
                    I = I(:,:,1);
                end
            end
            I = double(I);
            if isfield(info,'RescaleSlope'),     I = I * double(info.RescaleSlope);   end
            if isfield(info,'RescaleIntercept'), I = I + double(info.RescaleIntercept); end
            I = I - min(I(:));
            mx = max(I(:)); if mx>0, I = I/mx; end
            if isfield(info,'PhotometricInterpretation') && strcmpi(info.PhotometricInterpretation,'MONOCHROME1')
                I = 1 - I;
            end
            if ndims(I)==3 && size(I,3)==3
                I = rgb2gray(I);
            end
        otherwise
            Ir = imread(fpath);
            if ndims(Ir)==3, Ir = rgb2gray(Ir); end
            I = im2double(Ir);
    end
end
