function Iref = reflectImageOverLine(I, slope, intercept)
% REFLECTIMAGEOVERLINE - reflektuje sliku I preko prave y = slope*x + intercept.
% Obavezno radi u double i koristi interp2.
    I = im2double(I);

    [H, W] = size(I);
    [X, Y] = meshgrid(1:W, 1:H);

    m = slope;
    b = intercept;
    a = -m; bb = 1; c = -b;

    denom = a^2 + bb^2;
    D = a * X + bb * Y + c;

    Xr = X - 2 * a .* D / denom;
    Yr = Y - 2 * bb .* D / denom;

    Iref = interp2(X, Y, I, Xr, Yr, 'linear', 0);
end
