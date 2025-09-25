function [slope, intercept] = defineAxis(I, ax)
% Interaktivno biranje ≥2 tačke na UIAxes (uifigure-kompatibilno).
% dvoklikom završavaš crtanje polilinije.
    imshow(I, [], 'Parent', ax);
    title(ax, 'Nacrtaj poliliniju duž željene ose (≥2 tačke), pa dvoklik za kraj');

    % ROI polilinija (Image Processing Toolbox R2018b+)
    roi = drawpolyline(ax, 'LineWidth', 2);
    pos = roi.Position;           % Nx2 [x y]
    if size(pos,1) < 2
        if isvalid(roi), delete(roi); end
        error('Potrebno je označiti najmanje 2 tačke.');
    end

    x = pos(:,1); y = pos(:,2);
    p = polyfit(x, y, 1);         % y = m x + b
    slope = p(1);
    intercept = p(2);

    % prikaži dobijenu pravu
    xvals = linspace(1, size(I,2), 200);
    yvals = slope * xvals + intercept;
    hold(ax, 'on');
    plot(ax, xvals, yvals, 'r-', 'LineWidth', 2);
    hold(ax, 'off');

    if isvalid(roi)
        roi.Visible = 'off';      % opcionalno: sakrij ROI posle fitta
    end
end
