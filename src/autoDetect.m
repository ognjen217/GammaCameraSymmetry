function [slope, intercept, best] = autoDetect(I, varargin)
%AUTODETECT  Dvofazna (coarse→fine) automatska detekcija ose simetrije sa progress barom.
% [M,B,BEST] = AUTODETECT(I,'Name',Value,...)
% Name-Value:
%   'thetaStep'     (default 6)             % korak za COARSE fazu
%   'thetaRange'    (default [0 359])       % u stepenima (wrap je podržan)
%   'offsetStep'    (default round(min(H,W)/40) )   % korak za COARSE fazu
%   'thresholdPct'  (default 60)
%   'useScore'      (default true)
%   'ax'            axes handle (opciono: iscrtavanje najbolje ose)
%   'fig'           uifigure handle (modali progress/cancel)

    ip = inputParser;
    ip.addParameter('thetaStep', 12, @(x)isnumeric(x)&&isscalar(x)&&x>0);
    ip.addParameter('thetaRange', [0 180], @(x)isnumeric(x)&&numel(x)==2);
    ip.addParameter('offsetStep', [], @(x)isnumeric(x)&&isscalar(x)&&x>0);
    ip.addParameter('thresholdPct', 60, @(x)isnumeric(x)&&isscalar(x));
    ip.addParameter('useScore', true, @(x)islogical(x)||ismember(x,[0 1]));
    ip.addParameter('ax', [], @(x) isempty(x) || isgraphics(x,'axes'));
    ip.addParameter('fig', [], @(x) isempty(x) || isgraphics(x,'figure'));
    ip.parse(varargin{:});
    P = ip.Results;

    I = im2double(I); if size(I,3)>1, I = rgb2gray(I); end
    [H,W] = size(I);

    % --- Downscale radi brzine ---
    maxDim = 600; scale = min(1, maxDim/max([H,W]));
    Is = I; if scale < 1, Is = imresize(I, scale, 'bilinear'); end
    [Hs,Ws] = size(Is);

    if isempty(P.offsetStep), P.offsetStep = max(8, round(min([H,W])/40)); end
    offsetStep_s = max(3, round(P.offsetStep * scale));

    % --- COARSE skup uglova/offseta ---
    thetas = wrapTo360(P.thetaRange(1):P.thetaStep:P.thetaRange(2));
    R  = ceil(0.6*sqrt(Hs^2+Ws^2));
    offsets_s = -R:offsetStep_s:R;

    cx = (Ws+1)/2; cy = (Hs+1)/2;
    toLargeB = @(bs) bs/scale;

    best.scorePct  = -inf; best.theta_deg = NaN; best.offset_px = NaN;
    best.metrics   = [];   best.m         = 0;   best.b         = H/2;

    % ---------- PROGRESS DIALOG (modal, cancelable) ----------
    dlg = [];
    if ~isempty(P.fig) && isgraphics(P.fig,'figure')
        try
            dlg = uiprogressdlg(P.fig, ...
                'Title','Automatska detekcija', ...
                'Message','Priprema...', ...
                'Indeterminate','off', ...
                'Cancelable','on');
        catch, dlg = []; 
        end
    end

    % ===================== FAZA 1: COARSE =====================
    % oko najboljeg: θ ±3° sa korakom 1°, offset ±5 px (u velikim px, prevodimo u small)
    thetaFine = wrapTo360(best.theta_deg + (-6:1:+6));  % ±3° sa KORAKOM 1°
    dOffBig   = -15:1:+15;                                 % ±5 px
    totalCoarse = numel(thetas)*numel(offsets_s);
    dOffSmall = round(dOffBig * scale);

    totalFine = numel(thetaFine) * numel(dOffSmall);

    totalAll    = totalCoarse + totalFine;
    kdone       = 0;
    lastUpdate  = tic;

    % Coarse pretraga
    for it = 1:numel(thetas)
        th = thetas(it);
        m  = slopeFromTheta(th);

        n = [-m, 1]; n = n / max(eps, hypot(n(1),n(2)));   % jedinična normala

        for io = 1:numel(offsets_s)
            t = offsets_s(io);
            x0 = cx + t*n(1); y0 = cy + t*n(2);
            b_small = y0 - m*x0;

            Iref_s = reflectImageOverLine(Is, m, b_small);
            metrics = quickMetrics(Is, Iref_s);

            scPct = scoreFromMetrics(metrics, P.useScore); % 0..100
            if scPct > best.scorePct
                best.scorePct  = scPct;
                best.theta_deg = th;
                best.offset_px = t/scale;    % u velikim pikselima (radi konzistentnosti)
                best.metrics   = metrics;
                best.m         = m;
                best.b         = toLargeB(b_small);
            end

            % progress
            kdone = kdone + 1;
            if ~isempty(dlg) && (toc(lastUpdate) > 0.03 || kdone==1)
                dlg.Value   = kdone/totalAll;
                dlg.Message = sprintf('[1/2] θ = %5.1f°, test %d / %d', th, kdone, totalAll);
                drawnow;
                if dlg.CancelRequested, break; end
                lastUpdate = tic;
            end
        end
        if ~isempty(dlg) && dlg.CancelRequested, break; end
    end

    % Ako je otkazano tokom coarse, vrati trenutno najbolje
    if ~isempty(dlg) && dlg.CancelRequested
        slope = best.m; intercept = best.b; best.isSymmetric = (best.scorePct >= P.thresholdPct);
        closeSafe(dlg); drawBest(P.ax, slope, intercept, [H W], best);
        return;
    end

    % ===================== FAZA 2: FINE =====================
    % oko najboljeg: θ ±3° sa korakom 1°, offset ±5 px (u velikim px, prevodimo u small)
    thetaFine = wrapTo360(best.theta_deg + (-6:1:+6));  % ±3° sa KORAKOM 1°
    dOffBig   = -5:1:+5;                                 % ±5 px

    dOffSmall = round(dOffBig * scale);

    % recompute normal u small skali na osnovu θ
    for it = 1:numel(thetaFine)
        th = thetaFine(it);
        m  = slopeFromTheta(th);
        n  = [-m, 1]; n = n / max(eps, hypot(n(1),n(2)));

        % polazni offset (u small), dobijen iz best.offset_px
        t0_small = best.offset_px * scale;

        for io = 1:numel(dOffSmall)
            t = t0_small + dOffSmall(io);
            x0 = cx + t*n(1); y0 = cy + t*n(2);
            b_small = y0 - m*x0;

            Iref_s = reflectImageOverLine(Is, m, b_small);
            metrics = quickMetrics(Is, Iref_s);

            scPct = scoreFromMetrics(metrics, P.useScore);
            if scPct > best.scorePct
                best.scorePct  = scPct;
                best.theta_deg = th;
                best.offset_px = t/scale;
                best.metrics   = metrics;
                best.m         = m;
                best.b         = toLargeB(b_small);
            end

            % progress (dodajemo na već završene coarse testove)
            kdone = kdone + 1;
            if ~isempty(dlg) && (toc(lastUpdate) > 0.03)
                dlg.Value   = min(1, kdone/totalAll);
                dlg.Message = sprintf('[2/2] θ = %5.1f° (fine), %d / %d', th, kdone, totalAll);
                drawnow;
                if dlg.CancelRequested, break; end
                lastUpdate = tic;
            end
        end
        if ~isempty(dlg) && dlg.CancelRequested, break; end
    end

    slope     = best.m;
    intercept = best.b;
    best.isSymmetric = (best.scorePct >= P.thresholdPct);

    % Iscrtavanje i zatvaranje dlg
    drawBest(P.ax, slope, intercept, [H W], best);
    closeSafe(dlg);
end

% ---------- pomoćne / "inline" funkcije ----------
function m = slopeFromTheta(thDeg)
    % izbegava infinita oko 90/270°
    epsd = 1e-6;
    m = sind(thDeg) / max(epsd, cosd(thDeg));
end

function val = scoreFromMetrics(metrics, useScore)
    if useScore && isfield(metrics,'symmetry_score') && ~isempty(metrics.symmetry_score)
        val = double(metrics.symmetry_score);   % 0..100
    else
        val = 100*double(metrics.match_frac);   % 0..100
    end
end

function drawBest(ax, slope, intercept, hw, best)
    if isempty(ax) || ~isgraphics(ax,'axes'), return; end
    try
        hold(ax,'on');
        [xseg,yseg] = clipLineToImageLocal(slope, intercept, hw);
        plot(ax, xseg, yseg, 'r-', 'LineWidth', 2, 'PickableParts','none');
        hold(ax,'off');
        ttl = sprintf('Auto osa: θ=%.1f°  score≈%.1f%%', best.theta_deg, best.scorePct);
        title(ax, ttl, 'Interpreter','none');
    catch
    end
end

function closeSafe(dlg)
    if ~isempty(dlg) && isvalid(dlg)
        try close(dlg); catch, end
    end
end

% ===== brzi evaluator (isti kao ranije) =====
function M = quickMetrics(I, Iref)
    I    = im2double(I); Iref = im2double(Iref);
    valid = (I > 0.03) | (Iref > 0.03);
    win = 7;
    zncc = localZNCC(I, Iref, win); zncc = max(-1, min(1, zncc));
    [Gx1, Gy1] = imgradientxy(I); [Gx2, Gy2] = imgradientxy(Iref);
    g1 = hypot(Gx1, Gy1); g2 = hypot(Gx2, Gy2);
    cosang = (Gx1.*Gx2 + Gy1.*Gy2) ./ (g1.*g2 + eps);
    cosabs = abs(cosang);
    thr_g = prctile(g1(valid), 60);
    sal = (g1 > thr_g) | (g2 > thr_g);
    Tzncc = 0.50; Tgrad = 0.60;
    match_local = valid & (zncc >= Tzncc) & (cosabs >= Tgrad) & sal;

    match_frac    = nnz(match_local) / max(1, nnz(valid));
    mismatch_frac = 1 - match_frac;

    try [ssim_val, ~] = ssim(I, Iref); catch, ssim_val = NaN; end
    try corr_val = corr2(I, Iref);     catch, corr_val = NaN; end
    try E1 = edge(I,'canny'); E2 = edge(Iref,'canny'); catch, E1 = edge(I,'sobel'); E2 = edge(Iref,'sobel'); end
    interE     = nnz(E1 & E2);
    sumE       = nnz(E1) + nnz(E2);
    dice_edges = 2*interE / max(1,sumE);

    w_match = 0.40; w_ssim = 0.25; w_edges = 0.20; w_corr = 0.15;
    ssim_n  = clamp01(ssim_val);
    corr_n  = clamp01((corr_val+1)/2);
    edges_n = clamp01(dice_edges);
    match_n = clamp01(match_frac);
    score01 = w_match*match_n + w_ssim*ssim_n + w_edges*edges_n + w_corr*corr_n;
    symmetry_score = 100*score01*(1 - 0.2*mismatch_frac);

    M = struct('ssim', ssim_val, 'corr_intensity', corr_val, ...
               'dice_edges', dice_edges, 'match_frac', match_frac, ...
               'mismatch_frac', mismatch_frac, 'symmetry_score', symmetry_score);
end

function Z = localZNCC(A,B,win)
    if mod(win,2)==0, win=win+1; end
    k = ones(win)/(win*win);
    EA  = conv2(A,k,'same');  EB  = conv2(B,k,'same');
    EA2 = conv2(A.^2,k,'same'); EB2 = conv2(B.^2,k,'same');
    EAB = conv2(A.*B,k,'same');
    varA = max(EA2 - EA.^2, 0);
    varB = max(EB2 - EB.^2, 0);
    covAB = EAB - EA.*EB;
    Z = covAB ./ (sqrt(varA.*varB) + 1e-8);
end

function y = clamp01(x)
    if isnan(x), y=NaN; else, y = min(1,max(0,x)); end
end

function [xseg,yseg] = clipLineToImageLocal(m,b,hw)
    H = hw(1); W = hw(2);
    pts = [];
    y1 = m*1 + b; if y1>=1 && y1<=H, pts(end+1,:)=[1,y1]; end 
    yW = m*W + b; if yW>=1 && yW<=H, pts(end+1,:)=[W,yW]; end 
    if abs(m)>eps
        x1 = (1-b)/m; if x1>=1 && x1<=W, pts(end+1,:)=[x1,1]; end 
        xH = (H-b)/m; if xH>=1 && xH<=W, pts(end+1,:)=[xH,H]; end 
    else
        y = b; if y>=1 && y<=H, pts = [1,y; W,y]; end
    end
    if isempty(pts), xseg=[]; yseg=[]; return; end
    pts = round(pts,6); [~,ia]=unique(pts,'rows','stable'); pts=pts(ia,:);
    if size(pts,1)>2
        bestd=-inf; pair=[1 2];
        for i=1:size(pts,1)
            for j=i+1:size(pts,1)
                d = hypot(pts(i,1)-pts(j,1), pts(i,2)-pts(j,2));
                if d>bestd, bestd=d; pair=[i j]; end
            end
        end
        pts = pts(pair,:);
    end
    if size(pts,1)<2
        xseg=[1 W]; yseg=[m*1+b, m*W+b];
    else
        xseg=pts(:,1)'; yseg=pts(:,2)';
    end
end

function a = wrapTo360(a)
    a = mod(a,360);
end
