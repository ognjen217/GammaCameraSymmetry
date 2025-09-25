%% ==========================
%  Image utility helpers
%  (ostaju kako si imao)
%  ==========================
function Iout = normalizeImage(I)
    Iout = mat2gray(I);  % skalira u [0,1]
end

function Iout = enhanceContrast(I)
    Iout = imadjust(I);  % poboljšava kontrast
end

function Iout = denoiseImage(I)
    Iout = medfilt2(I, [3 3]);  % medijanski filter
end

function Iout = resizeImage(I, scale)
    Iout = imresize(I, scale);  % promena veličine
end

function Iout = binarizeImage(I, method)
    if nargin < 2, method = 'adaptive'; end
    if strcmpi(method, 'adaptive')
        T = adaptthresh(I, 0.5);
        Iout = imbinarize(I, T);
    else
        level = graythresh(I);
        Iout = imbinarize(I, level);
    end
end

function Iout = edgeDetectImage(I, method)
    if nargin < 2, method = 'Canny'; end
    Iout = edge(I, method);
end


%% ==========================
%  Saving / results helpers
%  ==========================

% Glavne “public” funkcije koje zoveš iz main_gui:
% 1) dirs = getDefaultDirs();
% 2) saveResultsCSV(dirs.results, baseName, res)
% 3) saveResultsMAT(dirs.results, baseName, res, extrasStruct)
% 4) saveMismatchOverlayPNG(dirs.figures, baseName, I, mismatchMask)
% 5) saveCurrentAxesPNG(dirs.figures, baseName, ax)   (opciono)

function dirs = getDefaultDirs()
% Određuje i kreira default /results i /results/figures u odnosu na main_gui lokaciju.
    here = fileparts(mfilename('fullpath'));
    % pretpostavka: utils_functions.m je u /src
    projectRoot = fileparts(here);
    resultsDir  = fullfile(projectRoot, 'results');
    figuresDir  = fullfile(resultsDir, 'figures');
    ensureDir(resultsDir);
    ensureDir(figuresDir);
    dirs = struct('projectRoot', projectRoot, 'results', resultsDir, 'figures', figuresDir);
end

function saveResultsCSV(outDir, baseName, res)
% Appenduje ili kreira CSV sa kolonom fajla i metrikama za svaku analizu.
% res: struct('numMismatch',..,'shift',..,'areaRatio',..)
    ensureDir(outDir);
    csvPath = fullfile(outDir, 'results.csv');
    row = resultRow(baseName, res);
    if exist(csvPath, 'file')
        T = readtable(csvPath);
        T = [T; row]; %#ok<AGROW>
    else
        T = row;
    end
    writetable(T, csvPath);
end

function saveResultsMAT(outDir, baseName, res, extras)
% Snima pojedinačni MAT fajl sa rezultatima + dodatnim info (npr. slope/intercept).
    ensureDir(outDir);
    matPath = fullfile(outDir, sprintf('%s_results_%s.mat', stripExt(baseName), timestamp()));
    if nargin < 4 || isempty(extras)
        save(matPath, 'res');
    else
        save(matPath, 'res', 'extras');
    end
end

function saveMismatchOverlayPNG(figuresDir, baseName, I, mismatchMask)
% Pravi PNG sa overlay-om piksela nepoklapanja (crveno) preko originala.
% Radi i bez Image Processing Toolbox-a (fallback).
    ensureDir(figuresDir);
    outPath = fullfile(figuresDir, sprintf('%s_overlay_%s.png', stripExt(baseName), timestamp()));
    % Ako je I RGB, pretvori u sivu (za overlay je lakše)
    if ndims(I) == 3
        Igray = rgb2gray(im2double(I));
    else
        Igray = im2double(I);
    end
    Igray = mat2gray(Igray);

    try
        % Prefer labeloverlay ako postoji (IPT)
        if exist('labeloverlay','file')
            RGB = labeloverlay(Igray, logical(mismatchMask), 'Transparency', 0.7, 'Colormap', [1 0 0]);
        else
            RGB = simpleOverlay(Igray, logical(mismatchMask));
        end
    catch
        RGB = simpleOverlay(Igray, logical(mismatchMask));
    end
    imwrite(RGB, outPath);
end

function saveCurrentAxesPNG(figuresDir, baseName, ax)
% Snimi trenutni prikaz axes-a (npr. sa nacrtanom osom) kao PNG.
    ensureDir(figuresDir);
    outPath = fullfile(figuresDir, sprintf('%s_view_%s.png', stripExt(baseName), timestamp()));
    fr = ancestor(ax, 'figure');
    % snimi samo axes region
    oldUnits = ax.Units; ax.Units = 'pixels';
    pos = ax.Position;
    ax.Units = oldUnits;

    F = getframe(ax); %#ok<GFLD>
    imwrite(F.cdata, outPath);
end


%% ==========================
%  Internal helpers
%  ==========================

function ensureDir(d)
    if ~exist(d, 'dir'), mkdir(d); end
end

function s = timestamp()
    s = datestr(now, 'yyyymmdd_HHMMSS');
end

function name = stripExt(fname)
    [~, name, ~] = fileparts(fname);
end

function row = resultRow(baseName, res)
% Kreira table sa jednom vrstom: Fajl, Nepoklapanja, Pomeraj, OdnosPovrsina, Timestamp
    if ~isfield(res,'numMismatch'), res.numMismatch = []; end
    if ~isfield(res,'shift'),       res.shift       = []; end
    if ~isfield(res,'areaRatio'),   res.areaRatio   = []; end
    row = table( string(baseName), ...
                 double(res.numMismatch), ...
                 double(res.shift), ...
                 double(res.areaRatio), ...
                 string(timestamp()), ...
                 'VariableNames', {'Fajl','Nepoklapanja','Pomeraj','OdnosPovrsina','Vreme'});
end

function RGB = simpleOverlay(Igray, mask)
% Fallback overlay: siva pozadina + crvena boja na maski (50% blend).
    Igray = mat2gray(Igray);
    if ~islogical(mask), mask = logical(mask); end
    R = Igray; G = Igray; B = Igray;
    % Pojačaj crveni kanal na maski, priguši G i B
    alpha = 0.5;
    R(mask) = (1-alpha)*R(mask) + alpha*1.0;
    G(mask) = (1-alpha)*G(mask) + alpha*0.0;
    B(mask) = (1-alpha)*B(mask) + alpha*0.0;
    RGB = cat(3, R, G, B);
end
