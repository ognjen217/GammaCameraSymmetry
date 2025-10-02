function Iref = reflectImageOverLine(I, slope, intercept)
    I = im2double(I);
    if any(isnan(I(:))), I(isnan(I)) = 0; end

    if any(size(I) >= 256)
        I = imgaussfilt(I, 0.6);
    end

    [H, W] = size(I);
    [X, Y] = meshgrid(1:W, 1:H);

    a = -slope; b = 1; c = -intercept;
    denom = a^2 + b^2;
    D = a*X + b*Y + c;

    Xr = X - 2*a.*D/denom;
    Yr = Y - 2*b.*D/denom;

    Iref = interp2(X, Y, I, Xr, Yr, 'linear', 0);
end
