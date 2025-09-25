function ensureDir(p)
%ENSUREDIR Kreira direktorijum ako ne postoji (bez greške ako postoji).
    if ~exist(p,'dir'), mkdir(p); end
end
