# GammaCameraSymmetry
Ovaj projekat je realizovan u okviru predmeta **Algoritmi obrade slike u automatici** i ima za cilj analizu simetrije snimaka gamma kamera korišćenjem algoritama obrade slike u MATLAB okruženju.

Autor: Ognjen Perić  
Broj indeksa: RA118/2021


## Opis projekta

Gamma kamere se koriste za medicinsku dijagnostiku, a simetrija snimka je važan parametar za procenu kvaliteta slike i ispravnost uređaja. Ovaj projekat implementira algoritme koji automatski analiziraju i kvantifikuju stepen simetrije u snimcima iz gamma kamera.

### Glavne funkcionalnosti
---

## Tok obrade — korak po korak

### 1) Učitavanje i preprocessing (`loadImages.m`)
- Učitava slike iz `data/original_images/` (DICOM ili standardne).
- Konvertuje u grayscale i normalizuje na `[0,1]`.
- Opcioni filteri: denoise, korekcija osvetljenja, CLAHE.

**Izlaz:** `I` (slika), opciono maska `M` i meta-podaci.

---

### 2) Definisanje ose (`defineAxis.m`)
- **Ručni režim:** korisnik bira osu u GUI-ju.
- **Auto režim:** predlog ose izračunat PCA/momentima.  
- Osa definisana tačkom + vektorom ili centrom + uglom.

**Izlaz:** `L = {p0, v}` ili `({cx, cy}, θ)`.

---

### 3) Refleksija (`reflectImageOverLine.m`)
- Pravi reflektovanu verziju slike `I_ref` preko ose `L`.
- Afi na transformacija sa interpolacijom (bilinear/bicubic).

**Izlaz:** `I_ref`.

---

### 4) Upoređivanje (`compareSymmetry.m`)
- Pixel-wise razlike: MAE, MSE, RMSE, NAD.
- Sličnost strukture: SSIM, NCC.
- Heat-map razlika + procenat piksela iznad praga τ.
- Skalarne ocene: `SymmetryScore`, `AsymmetryIndex`.

**Izlaz:** struktura `metrics` + `diffMap`.

---

### 5) Vizualizacija i eksport (`showResults.m`)
- Prikazuje original, refleksiju, overlay, osu simetrije.
- Heat-map i grafikoni profila.
- Snima u `results/`:
  - Slike (PNG/JPG),
  - `.csv` metrike,
  - `.mat` (metrics, diffMap).

---

## Brzi start

1. Stavi ulazne slike u `data/original_images/`.
2. Pokreni GUI `project_gamma_symmetry.m`.

Primer batch obrade:

matlab
inDir  = fullfile(pwd, 'data', 'original_images');
outDir = fullfile(pwd, 'results');

files = dir(fullfile(inDir, '*.*'));
[imgs, metas] = loadImages(files);

for k = 1:numel(imgs)
    I = imgs{k};

    axisParams = defineAxis(I, 'mode','auto', 'snapTo', 'vertical');
    I_ref = reflectImageOverLine(I, axisParams, 'interp','bicubic');
    metrics = compareSymmetry(I, I_ref, 'tau', 0.05, 'useSSIM', true);
    showResults(I, I_ref, axisParams, metrics, outDir, metas{k});
end


## Upotreba

1. Pokrenite MATLAB i otvorite ovaj projekat.
2. U glavnom skriptu (npr. `project_gamma_symmetry.m`), podesite putanju do slike gamma kamere koju želite da analizirate.
3. Pokrenite skriptu – algoritam će obraditi sliku, prikazati rezultate analize i sačuvati izveštaj ako je podešeno.
4. Vizuelizacija rezultata se automatski prikazuje u MATLAB figure prozoru.

## Instalacija

Za pokretanje ovog projekta potrebno je imati:
- MATLAB (verzija 2018 ili novija preporučena)
- Image Processing Toolbox (MATLAB dodatak za obradu slike)

Nije potrebna dodatna instalacija – dovoljno je preuzeti kod sa GitHub-a i otvoriti ga u MATLAB-u.

## Struktura projekta

- **main.m** – Glavni skript za pokretanje analize
- **functions/** – Pomoćne funkcije za obradu slike i analizu simetrije
- **data/** – Primeri slika gamma kamera
- **results/** – Rezultati analize i generisani izveštaji

## Algoritmi

Projekt koristi algoritme za detekciju simetrije kao što su:
- Korelacija između leve i desne (ili gornje i donje) polovine slike
- Proračun razlike piksela duž predložene ose simetrije
- Automatska optimizacija položaja ose simetrije radi maksimalnog poklapanja

**Napomena:** Projekat je edukativnog karaktera i namenjen je za demonstraciju algoritama obrade slike u medicinskim aplikacijama.
