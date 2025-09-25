# GammaCameraSymmetry
Ovaj projekat je realizovan u okviru predmeta **Algoritmi obrade slike u automatici** i ima za cilj analizu simetrije snimaka gamma kamera korišćenjem algoritama obrade slike u MATLAB okruženju.

Autor: Ognjen Perić  
Broj indeksa: RA118/2021

## Opis projekta
```matlab
project_root/
├─ data/
│ ├─ original_images/           # Ulazne slike (DICOM/PNG/JPG/…)
├─ src/
│ ├─ main_gui.m                 # GUI za ručni rad i testiranje
│ ├─ loadImages.m               # Učitavanje i osnovni preprocessing
│ ├─ defineAxis.m               # Definisanje ose simetrije
│ ├─ reflectImageOverLine.m     # Refleksija slike oko ose
│ ├─ compareSymmetry.m          # Proračun metrika simetrije
│ ├─ showResults.m              # Vizuelizacija i eksport
│ └─ utils_functions.m          # Pomoćne funkcije
├─ results/                     # Generisani rezultati i izveštaji
└─ project_gamma_symmetry.m 
```
---

## Šta projekat radi — korak po korak

### 1. Učitavanje i priprema (`loadImages.m`)
- Podržani formati: DICOM (`.dcm`), PNG, JPEG, TIFF.
- Normalizacija intenziteta u [0,1] ili [0,255].
- Po potrebi: uklanjanje šuma, korekcija osvetljenja, pojačanje kontrasta (CLAHE).
- Dobija se **čista grayscale slika** spremna za analizu.

---

### 2. Definisanje ose simetrije (`defineAxis.m`)
- **Ručni mod:** korisnik klikom unosi osu simetrije (npr. očekivana anatom­ska osa tela).
- **Automatski mod:** računa se predlog ose (npr. glavna komponenta preko PCA ili momenata).
- Parametri: položaj centra i ugao nagiba ose.

---

### 3. Refleksija slike (`reflectImageOverLine.m`)
- Slika se matematički preslikava preko zadate ose.
- Rezultat je **reflektovana verzija slike** `I_ref`, poravnata sa originalom.
- Implementirano kao afina transformacija uz interpolaciju.

---

### 4. Upoređivanje originala i refleksije (`compareSymmetry.m`)
Izračunavaju se različite **metrike simetrije**:

1. **Pixel-wise razlike**
   - **MAE (Mean Absolute Error)** – prosečna apsolutna razlika.
   - **MSE / RMSE** – kvadratna greška i njen koren.
   - **NAD (Normalized Absolute Difference)** – razlike normalizovane po intenzitetu.

2. **Metrike sličnosti strukture**
   - **SSIM (Structural Similarity Index, 0–1)** – meri koliko su strukture slične.
   - **NCC (Normalized Cross-Correlation)** – meri koliko su obrasci usklađeni.

3. **Mapa razlika (heat-map)**
   - Vizuelni prikaz razlika piksela.
   - Pragovanje (τ, npr. 5%) daje procenat piksela koji odstupaju više od praga.

4. **Globalni skorovi**
   - **SymmetryScore** = SSIM(I, I_ref) → bliže 1 znači bolja simetrija.
   - **AsymmetryIndex** = RMSE(I, I_ref) → niže vrednosti znače bolju simetriju.

---

### 5. Vizuelizacija i rezultati (`showResults.m`)
Za svaku sliku generiše se:

- **Original** i **reflektovana slika** (prikazane paralelno).
- **Overlay** originala i refleksije radi vizuelnog poređenja.
- **Osa simetrije** ucrtana na slici.
- **Heat-map razlika** sa legendom.
- **Grafikon profila** razlika (uzduž preseka normalnog na osu).
- Čuvanje u `results/`:
  - PNG/JPG grafike,
  - CSV fajl sa metrikama,
  - MAT fajl sa mapama i numeričkim vrednostima.

## Brzi start (primer batch obrade)

```matlab
inDir  = fullfile(pwd, 'data', 'original_images');
outDir = fullfile(pwd, 'results');

files = dir(fullfile(inDir, '*.*'));
[imgs, metas] = loadImages(files);

for k = 1:numel(imgs)
    I = imgs{k};

    % Definiši osu simetrije
    axisParams = defineAxis(I, 'mode','auto', 'snapTo','vertical');

    % Reflektuj
    I_ref = reflectImageOverLine(I, axisParams, 'interp','bicubic');

    % Izračunaj metrike
    metrics = compareSymmetry(I, I_ref, 'tau',0.05, 'useSSIM',true);

    % Prikaži i sačuvaj
    showResults(I, I_ref, axisParams, metrics, outDir, metas{k});
end

```
**Napomena:** Projekat je edukativnog karaktera i namenjen je za demonstraciju algoritama obrade slike u medicinskim aplikacijama.
