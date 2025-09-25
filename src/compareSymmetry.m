function [numMismatch, shift, areaRatio, mismatchMask, metrics] = compareSymmetry(I, Iref)
% Robustna procena simetrije:
%  - Lokalna ZNCC (patch-wise) + doslednost gradijenta + salijentnost
%  - Mismatch = validna_zona & ~verified_match
%  - Globalna statistička provera (nul-model sa "drmanim" osama)
%  - Bogat paket metrika + verified match mask (metrics.match_mask)
%
% Ulazi:  I, Iref  -> double [0,1], iste dimenzije

    I    = im2double(I);
    Iref = im2double(Iref);

    [H, W] = size(I);
    valid = (I > 0.03) | (Iref > 0.03);   % zona interesa (ne mrak)

    % ---------- 1) LOKALNI KRITERIJUMI ----------

    % 1a) ZNCC (patch-wise) za svaki piksel
    win = 9;                             % širina kvadratnog prozora (neparan)
    zncc = localZNCC(I, Iref, win);      % [-1,1]
    zncc = max(-1, min(1, zncc));        % sigurnost

    % 1b) Doslednost gradijenta (pravac ivice treba da se slaže/ogleda)
    [Gx1, Gy1] = imgradientxy(I);
    [Gx2, Gy2] = imgradientxy(Iref);

    g1 = hypot(Gx1, Gy1);
    g2 = hypot(Gx2, Gy2);

    cosang = (Gx1.*Gx2 + Gy1.*Gy2) ./ (g1.*g2 + eps);  % [-1,1]
    cosabs = abs(cosang);                              % napomena: ogledanje može inverzno da okrene normalu

    % 1c) Salijentnost (uvedi prag na jačinu gradijenta)
    thr_g = prctile(g1(valid), 60);   % 60. percentil unutar valid zone
    sal = (g1 > thr_g) | (g2 > thr_g);

    % 1d) Strogi lokalni match
    Tzncc = 0.55;            % prag za ZNCC (možeš pooštriti na 0.6)
    Tgrad = 0.60;            % prag za orijentacionu podudarnost
    match_local = valid & (zncc >= Tzncc) & (cosabs >= Tgrad) & sal;

    % ---------- 2) MISMATCH po pikselu ----------
    % Umesto praga na |I-Iref|, mismatch je prosto: valid & ~verified_match
    mismatchMask = valid & ~match_local;
    numMismatch  = nnz(mismatchMask);

    % ---------- 3) "Shift" i "areaRatio" (kompatibilnost) ----------
    CC = bwconncomp(mismatchMask);
    stats = regionprops(CC, 'Centroid', 'Area');
    if numel(stats) >= 2
        [~, idxs] = sort([stats.Area], 'descend');
        c1 = stats(idxs(1)).Centroid; c2 = stats(idxs(2)).Centroid;
        shift = norm(c1 - c2);
        areaRatio = stats(idxs(1)).Area / max(1,stats(idxs(2)).Area);
    else
        shift = NaN; areaRatio = NaN;
    end

    % ---------- 4) DODATNE METRIKE (kao ranije) ----------
    % SSIM i korelacija
    try, [ssim_val, ~] = ssim(I, Iref); catch, ssim_val = NaN; end
    try, corr_val = corr2(I, Iref);     catch, corr_val = NaN; end

    % Ivicne metrike
    try, E1 = edge(I, 'canny'); E2 = edge(Iref, 'canny');
    catch, E1 = edge(I, 'sobel'); E2 = edge(Iref, 'sobel');
    end
    interE        = nnz(E1 & E2);
    sumE          = nnz(E1) + nnz(E2);
    dice_edges    = 2*interE / max(1,sumE);
    unionE        = nnz(E1 | E2);
    jaccard_edges = interE / max(1,unionE);
    dist1         = bwdist(E2);
    dist2         = bwdist(E1);
    hausdorff_edges = max([max(dist1(E1)), max(dist2(E2))]);
    chamfer_mean    = (mean(dist1(E1)) + mean(dist2(E2))) / 2;
    chamfer_max     = max([max(dist1(E1)), max(dist2(E2))]);

    % Udeo poklapanja (strogi, verifikovani)
    match_frac = nnz(match_local) / nnz(valid);
    mismatch_frac = 1 - match_frac;

    % ---------- 5) NUL-MODEL (da ne "izmišljamo" simetriju) ----------
    % Napravi 12 jitter refleksija (mala promena ugla i pomeraja),
    % izračunaj isti strogi match i uzmi 95. percentil.
    null_fracs = permutationNullSymmetry(I, 12, win, Tzncc, Tgrad, thr_g);
    null95 = prctile(null_fracs, 95);
    significant = match_frac > null95;

    if ~significant
        % Ako nije statistički iznad slučaja -> ne prikazuj match
        match_local = false(size(match_local));
        mismatchMask = valid;             % praktično sve validno je "nepoklapanje"
        match_frac = 0;
        mismatch_frac = 1;
    end

    % ---------- 6) Kompozitni skor (0..100) ----------
    w_match = 0.40; w_ssim = 0.25; w_edges = 0.20; w_corr = 0.15;
    ssim_n  = clamp01(ssim_val);
    corr_n  = clamp01((corr_val+1)/2);
    edges_n = clamp01(dice_edges);
    match_n = clamp01(match_frac);
    score01 = w_match*match_n + w_ssim*ssim_n + w_edges*edges_n + w_corr*corr_n;
    symmetry_score = 100*score01*(1 - 0.2*mismatch_frac);

    % ---------- 7) Izlazni paket ----------
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
        'match_mask', match_local, ...    % <<< ZELENA maska (verifikovana)
        'zncc', zncc, ...
        'grad_consistency', cosabs ...
    );
end

% ================== LOKALNE POMOĆNE ================== %

function Z = localZNCC(A, B, win)
% ZNCC za svaki piksel u "validnoj" zoni: 
%   Z = (E[AB] - E[A]E[B]) / (sqrt(VarA VarB) + eps)
% implementirano preko box-filtera (konvolucije).
    if mod(win,2)==0, win = win+1; end
    k = ones(win) / (win*win);
    EA  = conv2(A, k, 'same');
    EB  = conv2(B, k, 'same');
    EA2 = conv2(A.^2, k, 'same');
    EB2 = conv2(B.^2, k, 'same');
    EAB = conv2(A.*B, k, 'same');

    varA = max(EA2 - EA.^2, 0);
    varB = max(EB2 - EB.^2, 0);
    covAB = EAB - EA.*EB;

    Z = covAB ./ (sqrt(varA.*varB) + 1e-8);
end

function null_fracs = permutationNullSymmetry(I, K, win, Tzncc, Tgrad, thr_g)
% Globalni nul-model: reflektuj I preko nasumičnih linija (ugao +-15°, pomeraj +-5%),
% pa izračunaj udeo piksela koji prođu strogi match. Brzo i dovoljno dobro.
    [H,W] = size(I);
    % Linija referenca = dijagonala – nije bitno, jer se randomizuje
    m0 = 0; b0 = H/2;   % početna aproks. (ionako ćemo jitrovati)

    null_fracs = zeros(1,K);
    for k = 1:K
        dtheta = deg2rad( -15 + 30*rand );       % +/-15°
        dm     = tan(dtheta);                    % mala promena nagiba
        db     = (rand-0.5) * 0.10 * max(H,W);   % +/-5% dijagonale (ukupno 10%)

        m = m0 + dm;
        b = b0 + db;

        Iref_k = reflectImageOverLine(I, m, b);

        % Lokalni kriterijumi (isti kao gore)
        zncc = localZNCC(I, Iref_k, win);
        [Gx1, Gy1] = imgradientxy(I);
        [Gx2, Gy2] = imgradientxy(Iref_k);
        g1 = hypot(Gx1, Gy1); g2 = hypot(Gx2, Gy2);
        cosang = (Gx1.*Gx2 + Gy1.*Gy2) ./ (g1.*g2 + eps);
        cosabs = abs(cosang);
        valid = (I>0.03) | (Iref_k>0.03);
        sal   = (g1 > thr_g) | (g2 > thr_g);

        match_local = valid & (zncc >= Tzncc) & (cosabs >= Tgrad) & sal;
        null_fracs(k) = nnz(match_local) / max(1, nnz(valid));
    end
end

function y = clamp01(x)
    if isnan(x), y = NaN; return; end
    y = min(1,max(0,x));
end
