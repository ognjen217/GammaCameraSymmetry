function RGB = simpleOverlay(Igray, mask)
    Igray = mat2gray(Igray);
    if ~islogical(mask), mask = logical(mask); end
    R = Igray; G = Igray; B = Igray;
    alpha = 0.5;
    R(mask) = (1-alpha)*R(mask) + alpha*1.0;
    G(mask) = (1-alpha)*G(mask) + alpha*0.0;
    B(mask) = (1-alpha)*B(mask) + alpha*0.0;
    RGB = cat(3, R, G, B);
end
