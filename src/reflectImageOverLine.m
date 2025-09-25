function Iref = reflectImageOverLine(I, slope, intercept)
    I = im2double(I);   % <<< stabilno za interp2

    [H, W] = size(I);
    [X, Y] = meshgrid(1:W, 1:H);

    m = slope;
    b = intercept;
    a = -m; bb = 1; c = -b;

    denom = a^2 + bb^2;
    D = a * X + bb * Y + c;

    Xr = X - 2 * a .* D / denom;
    Yr = Y - 2 * bb .* D / denom;

    Iref = interp2(X, Y, I, Xr, Yr, 'linear', 0);  % double, 0..1
end
