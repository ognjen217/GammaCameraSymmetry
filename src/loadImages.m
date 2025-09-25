function [images, names] = loadImages()
% Dijalogsko biranje i učitavanje; vraća slike + pune putanje (names)

    [files, path] = uigetfile( ...
        {'*.dcm;*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', 'Sve podržane (*.dcm, *.png, *.jpg, *.bmp, *.tif)'; ...
         '*.dcm', 'DICOM (*.dcm)'; ...
         '*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff', 'Raster slike'}, ...
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
        fpath     = fullfile(path, files{i});
        images{i} = readImageAny(fpath);  % util
        names{i}  = fpath;                % VAŽNO: puna putanja
    end
end
