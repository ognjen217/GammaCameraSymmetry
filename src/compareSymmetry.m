function [numMismatch, shift, areaRatio, mismatchMask, metrics] = compareSymmetry(I, Iref)
% Robustnija procena simetrije (foreground-only, adaptivni pragovi).
% Potpis i redosled izlaza su nepromenjeni.

    % ---------- priprema ----------
    I    = im2double(I);
    Iref = im2double(Iref);
    if ndims(I)==3,    I    = rgb2gray(I);    end
    if ndims(Iref)==3, Iref = rgb2gray(Iref); end
    I    = mat2gray(I);
    Iref = mat2gray(Iref);

    % Foreground maska (ignoriše pozadinu)
    fg = computeForeground(I, Iref);      % logička maska
    if nnz(fg) == 0
        fg = true(size(I));               % fallback – sve je foreground
    end

    % ---------- lokalna korelacija (ZNCC) ----------
    win  = 9;
    zncc = localZNCC(I, Iref, win);
    zncc(~isfinite(zncc)) = 0;

    % ---------- gradijenti i njihove orijentacije ----------
    [Gx1,Gy1] = imgradientxy(I);
    [Gx2,Gy2] = imgradientxy(Iref);
    g1   = hypot(Gx1,Gy1);
    g2   = hypot(Gx2,Gy2);
    cosang = (Gx1.*Gx2 + Gy1.*Gy2) ./ (g1.*g2 + eps);
    cosabs = abs(cosang);

    % ---------- saliency (jači rubovi/pikseli) ----------
    g_all = max(g1,g2);
    thr_g = max( eps, prctile(g_all(fg), 70) );  % adaptivno – gornjih ~30% je "salient"
    sal   = (g1 > thr_g) | (g2 > thr_g);

    % ---------- adaptivni pragovi za meč ----------
    % uzmi srednji do visoki percentile; obezbedi donju granicu
    Tzncc = max(0.45, prctile(zncc(fg), 60));    % 0.45–0.8 tipično
    Tgrad = max(0.50, prctile(cosabs(fg), 60));  % 0.5–0.9 tipično

    valid = fg; % samo na foreground pikselima
    match_local = valid & (zncc >= Tzncc) & (cosabs >= Tgrad) & sal;

    mismatchMask = valid & ~match_local;
    numMismatch  = nnz(mismatchMask);

    % ---------- pomeraj i odnos površina (samo na FG mismatchevima) ----------
    CC = bwconncomp(mismatchMask);
    stats = regionprops(CC, 'Centroid', 'Area');
    if numel(stats) >= 2
        [~, idxs] = sort([stats.Area], 'descend');
        c1 = stats(idxs(1)).Centroid; c2 = stats(idxs(2)).Centroid;
        shift = norm(c1 - c2);
        areaRatio = stats(idxs(1)).Area / max(1,stats(idxs(2)).Area);
    elseif isscalar(stats)
        shift = NaN; areaRatio = Inf;
    else
        shift = NaN; areaRatio = NaN;
    end

    % ---------- globalne metrike s robusnim rukovanjem ----------
    ssim_val = safeSSIM(I, Iref);
    corr_val = safeCorr2(I, Iref);

    % Dice/Jaccard na ivicama (na FG regionu)
    [dice_edges, jaccard_edges, hausdorff_edges, chamfer_mean, chamfer_max] = edgeMetrics(I, Iref, fg);

    % Frakcije (samo FG)
    match_frac    = nnz(match_local) / max(1, nnz(valid));
    mismatch_frac = 1 - match_frac;

    % ---------- permutaciona nulta distribucija (opciono) ----------
    % Napomena: više nije "kazna" (ne poništavamo rezultat), već samo indikator.
    null_fracs = permutationNullSymmetry(I, 8, win, Tzncc, Tgrad, thr_g); % 8 je dovoljno brzo u GUI-ju
    null95 = prctile(null_fracs, 95);
    significant = match_frac > null95;

    % Skor (0–100): težine podesive
    w_match = 0.45; w_ssim = 0.25; w_edges = 0.20; w_corr = 0.10;
    ssim_n  = clamp01(ssim_val);
    corr_n  = clamp01((corr_val+1)/2);
    edges_n = clamp01(dice_edges);
    score01 = w_match*match_frac + w_ssim*ssim_n + w_edges*edges_n + w_corr*corr_n;
    symmetry_score = 100 * score01 * (1 - 0.15*mismatch_frac);

    % ---------- pakovanje izlaza ----------
    metrics = struct( ...
        'ssim', ssim_val, ...
        'corr_intensity', corr_val, ...
        'dice_edges', dice_edges, ...
        'jaccard_edges', jaccard_edges, ...
        'hausdorff_edges', hausdorff_edges, ...
        'chamfer_mean', chamfer_mean, ...
        'chamfer_max', chamfer_max, ...
        'match_frac', match_frac, ...
        'mismatch_frac', mismatch_frac, ...
        'symmetry_score', symmetry_score, ...
        'significant', significant, ...
        'null95_match_frac', null95, ...
        'match_mask', match_local, ...   % << za overlay ako želiš
        'zncc', zncc, ...
        'grad_consistency', cosabs, ...
        'thresholds', struct('Tzncc',Tzncc,'Tgrad',Tgrad,'thr_g',thr_g) ...
    );
end

% ================= helpers =================

function fg = computeForeground(I, Iref)
    % Otsu + relativni prag + čišćenje; radi nad obe slike pa spaja.
    t1 = graythresh(I);
    t2 = graythresh(Iref);
    t  = max([t1, t2, 0.05]);           % donji limit (0.05)
    fg = (I >= t) | (Iref >= t);
    fg = bwareaopen(fg, max(30, round(0.0005*numel(I))));
    fg = imfill(fg,'holes');
end

function Z = localZNCC(A, B, win)
    if mod(win,2)==0, win = win+1; end
    k   = ones(win) / (win*win);
    EA  = conv2(A, k, 'same');  EB  = conv2(B, k, 'same');
    EA2 = conv2(A.^2, k, 'same');EB2 = conv2(B.^2, k, 'same');
    EAB = conv2(A.*B, k, 'same');
    varA = max(EA2 - EA.^2, 0);  varB = max(EB2 - EB.^2, 0);
    covAB = EAB - EA.*EB;
    Z = covAB ./ (sqrt(varA.*varB) + 1e-8);
    Z(~isfinite(Z)) = 0;
end

function null_fracs = permutationNullSymmetry(I, K, win, Tzncc, Tgrad, thr_g)
    % Generiše "fake" ose da bi se videlo koliki match se dobija slučajno.
    [H,W] = size(I);
    null_fracs = zeros(1,K);
    for k = 1:K
        % nasumične male rot/trans devijacije oko centra
        dtheta = deg2rad( -15 + 30*rand );
        dm     = tan(dtheta);
        db     = (rand-0.5) * 0.08 * max(H,W);

        Iref_k = reflectImageOverLine(I, dm, H/2 + db);

        zncc = localZNCC(I, Iref_k, win);
        [Gx1, Gy1] = imgradientxy(I);
        [Gx2, Gy2] = imgradientxy(Iref_k);
        g1 = hypot(Gx1, Gy1); g2 = hypot(Gx2, Gy2);
        cosang = (Gx1.*Gx2 + Gy1.*Gy2) ./ (g1.*g2 + eps);
        cosabs = abs(cosang);

        fg   = computeForeground(I, Iref_k);
        sal  = (g1 > thr_g) | (g2 > thr_g);

        match_local = fg & (zncc >= Tzncc) & (cosabs >= Tgrad) & sal;
        null_fracs(k) = nnz(match_local) / max(1, nnz(fg));
    end
end

function s = safeSSIM(A,B)
    try
        s = ssim(A,B);
    catch
        s = NaN;
    end
    if ~isfinite(s), s = NaN; end
end

function c = safeCorr2(A,B)
    try
        c = corr2(A,B);
    catch
        c = NaN;
    end
    if ~isfinite(c), c = NaN; end
end

function [dice_edges, jaccard_edges, hausdorff_edges, chamfer_mean, chamfer_max] = edgeMetrics(I, Iref, fg)
    try
        E1 = edge(I,'canny'); 
        E2 = edge(Iref,'canny');
    catch
        E1 = edge(I,'sobel'); 
        E2 = edge(Iref,'sobel');
    end
    if nargin>=3 && ~isempty(fg)
        E1 = E1 & fg;  E2 = E2 & fg;
    end
    inter  = nnz(E1 & E2);
    sumE   = nnz(E1) + nnz(E2);
    unionE = nnz(E1 | E2);

    dice_edges    = inter / max(1, 0.5*sumE);   % ekvivalent 2*inter/sumE
    jaccard_edges = inter / max(1, unionE);

    % Chamfer/Hausdorff
    if any(E1(:)) && any(E2(:))
        d1 = bwdist(E2);
        d2 = bwdist(E1);
        hausdorff_edges = max([max(d1(E1)), max(d2(E2))]);
        chamfer_mean    = (mean(d1(E1)) + mean(d2(E2))) / 2;
        chamfer_max     = max([max(d1(E1)), max(d2(E2))]);
    else
        hausdorff_edges = NaN;
        chamfer_mean    = NaN;
        chamfer_max     = NaN;
    end
end

function y = clamp01(x)
    if isnan(x), y = NaN; return; end
    y = min(1,max(0,x));
end
