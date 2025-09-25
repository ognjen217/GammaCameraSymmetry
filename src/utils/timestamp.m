function s = timestamp()
%TIMESTAMP ISO-like string bez nedozvoljenih znakova za fajl.
    s = datestr(now, 'yyyy-mm-dd HH:MM:SS');
end
