function name = stripExt(fname)
%STRIPEXT Skida ekstenziju iz imena fajla.
    [~, name, ~] = fileparts(fname);
end
