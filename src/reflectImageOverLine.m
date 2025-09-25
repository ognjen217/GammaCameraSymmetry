function Iref = reflectImageOverLine(I, slope, intercept)
% REFLECTIMAGEOVERLINE  Reflektuje sliku I preko prave y = slope*x + intercept.
% - radi u double [0,1]
% - blago prefiltriranje smanjuje aliasing pre interp2

    I = im2double(I);
    if any(isnan(I(:))), I(isnan(I)) = 0; end

    % Blago zaglađivanje protiv aliasinga (ne menja mnogo detalje)
    if any(size(I) >= 256)
        I = imgaussfilt(I, 0.6);
    end

    [H, W] = size(I);
    [X, Y] = meshgrid(1:W, 1:H);

    % Analitički odraz tačke (x,y) u odnosu na ax+by+c=0, gde je linija y=mx+b:
    % a = -m, b = 1, c = -b
    a = -slope; b = 1; c = -intercept;
    denom = a^2 + b^2;
    D = a*X + b*Y + c;

    Xr = X - 2*a.*D/denom;
    Yr = Y - 2*b.*D/denom;

    % Subpixel interpolacija
    Iref = interp2(X, Y, I, Xr, Yr, 'linear', 0);
end
