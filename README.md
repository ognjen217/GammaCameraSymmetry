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
│ ├─ autoDetect.m               # Automatska pretraga ose simetrije
│ └─ utils_functions.m          # Pomoćne funkcije
├─ results/                     # Generisani rezultati i izveštaji
└─ project_gamma_symmetry.m     # fajl koji je potrebno pokrenuti u komandnoj liniji
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

---

### 6. Automatska detekcija ose (`autoDetect.m`)
Ova funkcionalnost omogućava da se osa simetrije pronađe potpuno automatski, bez ručnog klikanja korisnika. Implementacija je **dvofazna (coarse→fine) pretraga**:

1. **Coarse pretraga (grubi korak)**  
   - Ispituju se kandidati za osu u opsegu **0–360°**, sa unapred zadatim korakom (npr. 6°).  
   - Za svaku osu, pomera se kroz više offseta (pomeraja od centra).  
   - Računaju se brze metrike sličnosti (`quickMetrics`):
     - Pixel match fraction,
     - SSIM,
     - Dice overlap ivica,
     - Cross-correlation.  
   - Kombinovani skor se koristi kao kriterijum.

2. **Fine pretraga (fino podešavanje)**  
   - Oko najbolje pronađene ose iz coarse faze, testira se uži opseg:
     - Uglovi ±3° oko najbolje vrednosti (korak 1°),
     - Offset ±5 px od najboljeg.  
   - Time se vrši lokalno „doterivanje".

3. **Rezultat**  
   - Vraća se **nagib i odsečak prave** u koordinatama slike.  
   - Na glavnom prikazu u GUI-u crta se crvena linija isečena na okvir slike.  
   - Izračunava se i indikator `isSymmetric` (DA/NE) na osnovu praga (`thresholdPct`, default 60%).  
   - Uz progres bar (`uiprogressdlg`) korisnik može pratiti koliko je testova ostalo i opcionalno prekinuti računanje.

---

**Napomena:** Projekat je edukativnog karaktera i namenjen je za demonstraciju algoritama obrade slike u medicinskim aplikacijama.
