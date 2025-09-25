function I = readImageAny(fpath)

    if ~isfile(fpath)
        error('Fajl ne postoji: %s', fpath);
    end

    [~,~,ext] = fileparts(fpath);
    ext = lower(ext);

    switch ext
        case '.dcm'
            info = dicominfo(fpath);
            Id   = dicomread(info);

            if ndims(Id) == 3 && size(Id,3) ~= 3
                k  = round(size(Id,3)/2);
                Id = Id(:,:,k);
            elseif ndims(Id) == 4
                k  = round(size(Id,4)/2);
                Id = Id(:,:,:,k);
                if size(Id,3) ~= 3
                    Id = Id(:,:,1);
                end
            end

            Id = double(Id);
            if isfield(info,'RescaleSlope'),     Id = Id * double(info.RescaleSlope);   end
            if isfield(info,'RescaleIntercept'), Id = Id + double(info.RescaleIntercept); end

            Id = Id - min(Id(:));
            mx = max(Id(:)); if mx>0, Id = Id/mx; end

            if isfield(info,'PhotometricInterpretation') && strcmpi(info.PhotometricInterpretation,'MONOCHROME1')
                Id = 1 - Id;
            end

            if ndims(Id)==3 && size(Id,3)==3
                Id = rgb2gray(Id);
            end

            I = Id;

        otherwise
            Ir = imread(fpath);
            if ndims(Ir) == 3
                Ir = rgb2gray(Ir);
            end
            I = im2double(Ir);
    end
end
