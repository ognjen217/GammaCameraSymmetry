function saveResultsCSV(outDir, baseName, res)
%SAVERESULTSCSV Kreira ili dopunjuje results.csv u outDir.
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
