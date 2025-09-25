function [images, names] = loadImages()
% Učitava PNG/JPG/TIF i DICOM tako da GUI uvek dobije 2D grayscale (double, 0..1)

    [files, path] = uigetfile( ...
        {'*.dcm;*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff','Sve podržane (*.dcm, *.png, *.jpg, *.bmp, *.tif)'; ...
         '*.dcm','DICOM (*.dcm)'; ...
         '*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff','Raster slike'}, ...
        'Izaberi više slika', 'MultiSelect','on');

    if isequal(files,0)
        images = {};
        names  = {};
        return;
    end

    if ~iscell(files); files = {files}; end
    N = numel(files);
    images = cell(1,N);
    names  = cell(1,N);

    for i = 1:N
        fpath    = fullfile(path, files{i});
        images{i} = readImageAny(fpath);   % <<< robustno učitavanje (ispod)
        names{i}  = files{i};
    end
end

% ------------------------------------------------------------
function I = readImageAny(fpath)
% Vraća 2D grayscale (double, 0..1), spremno za imshow/obradu

    [~,~,ext] = fileparts(fpath);
    ext = lower(ext);

    switch ext
        case '.dcm'
            info = dicominfo(fpath);
            Id   = dicomread(info);     % moze biti 2D/3D/4D, 12/16-bit itd.

            % --- Izbor frame-a (ako je multi-frame)
            if ndims(Id) == 3 && size(Id,3) ~= 3
                k  = round(size(Id,3)/2);
                Id = Id(:,:,k);
            elseif ndims(Id) == 4
                k  = round(size(Id,4)/2);
                Id = Id(:,:,:,k);
                if size(Id,3) ~= 3          % ako nije RGB, svedi na 2D
                    Id = Id(:,:,1);
                end
            end

            Id = double(Id);

            % --- RescaleSlope / RescaleIntercept (CT i sl.)
            if isfield(info,'RescaleSlope'),     Id = Id * double(info.RescaleSlope);   end
            if isfield(info,'RescaleIntercept'), Id = Id + double(info.RescaleIntercept); end

            % --- Normalizacija u [0,1]
            Id = Id - min(Id(:));
            mx = max(Id(:));
            if mx > 0, Id = Id / mx; end

            % --- MONOCHROME1 -> invertuj
            if isfield(info,'PhotometricInterpretation') && strcmpi(info.PhotometricInterpretation,'MONOCHROME1')
                Id = 1 - Id;
            end

            % Ako je RGB DICOM, svedi na grayscale (za obradu je dovoljna 2D)
            if ndims(Id) == 3 && size(Id,3) == 3
                Id = rgb2gray(Id);
            end

            I = Id;   % double 0..1, 2D

        case {'.png','.jpg','.jpeg','.bmp','.tif','.tiff'}
            Ir = imread(fpath);
            if ndims(Ir) == 3
                Ir = rgb2gray(Ir);
            end
            I = im2double(Ir);

        otherwise
            error('Nepodržana ekstenzija: %s', ext);
    end
end
