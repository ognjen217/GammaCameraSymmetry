function saveResultsCSV(outDir, baseName, res)
    ensureDir(outDir);
    csvPath = fullfile(outDir, 'results.csv');
    row = resultRow(baseName, res);

    if exist(csvPath, 'file')
        T = readtable(csvPath);
        T = [T; row]; 
    else
        T = row;
    end
    writetable(T, csvPath);
end
