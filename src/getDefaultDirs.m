function dirs = getDefaultDirs()
%GETDEFAULTDIRS Vraća standardne putanje projekta i kreira ih ako ne postoje.
%   dirs struct polja:
%     .root
%     .data
%     .data_original
%     .data_processed
%     .data_ground_truth
%     .results
%     .docs
%
%   Funkcija je robusna na to odakle je pozvana (GUI, skripta, itd.).

    % Polazna tačka = lokacija ovog .m fajla
    here = fileparts(mfilename('fullpath'));

    % Pronađi project_root (popeni se dok ne nađe "data" ili "src")
    candidate = here;
    maxUp = 6;
    found = false;
    for i = 1:maxUp
        if exist(fullfile(candidate, 'data'), 'dir') || exist(fullfile(candidate, 'src'), 'dir')
            found = true;
            break;
        end
        candidate = fileparts(candidate);
    end
    if ~found
        % fallback: jedan nivo iznad
        candidate = fileparts(here);
    end
    root = candidate;

    data   = fullfile(root, 'data');
    dOrig  = fullfile(data, 'original_images');
    dProc  = fullfile(data, 'processed_images');
    dGT    = fullfile(data, 'ground_truth');
    results= fullfile(root, 'results');
    docs   = fullfile(root, 'docs');

    % Kreiraj ako ne postoje
    mkIf(results); mkIf(dProc); mkIf(dOrig); mkIf(dGT); mkIf(docs);

    dirs = struct( ...
        'root', root, ...
        'data', data, ...
        'data_original', dOrig, ...
        'data_processed', dProc, ...
        'data_ground_truth', dGT, ...
        'results', results, ...
        'docs', docs);

end

function mkIf(p)
    if ~exist(p, 'dir'); mkdir(p); end
end
