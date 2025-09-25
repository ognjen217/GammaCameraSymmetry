# GammaCameraSymmetry
Ovaj projekat je realizovan u okviru predmeta **Algoritmi obrade slike u automatici** i ima za cilj analizu simetrije snimaka gamma kamera korišćenjem algoritama obrade slike u MATLAB okruženju.

Autor: Ognjen Perić  
Broj indeksa: RA118/2021

## Opis projekta

project_root/
├─ data/
│ ├─ original_images/ # Ulazne slike (DICOM/PNG/JPG/…)
├─ src/
│ ├─ main_gui.m # GUI za ručni rad i testiranje
│ ├─ loadImages.m # Učitavanje i osnovni preprocessing
│ ├─ defineAxis.m # Definisanje ose simetrije
│ ├─ reflectImageOverLine.m # Refleksija slike oko ose
│ ├─ compareSymmetry.m # Izračun metrika simetrije
│ ├─ showResults.m # Vizuelizacija i eksport
│ └─ utils_functions.m # Pomoćne funkcije
├─ results/ # Generisani rezultati i izveštaji
└─ project_gamma_symmetry.m 

Gamma kamere se koriste za medicinsku dijagnostiku.
Ovaj projekat implementira algoritme koji automatski analiziraju i kvantifikuju stepen simetrije u snimcima iz gamma kamera.

1. Postaviti ulazne slike u `data/original_images/` ili kroz meni u GUI-ju izabrati sliku sa računara.
2. Pokreni GUI `project_gamma_symmetry.m`.

## Algoritmi

Projekt koristi algoritme za detekciju simetrije kao što su:
- Korelacija između leve i desne (ili gornje i donje) polovine slike
- Proračun razlike piksela duž predložene ose simetrije
- Automatska optimizacija položaja ose simetrije radi maksimalnog poklapanja

**Napomena:** Projekat je edukativnog karaktera i namenjen je za demonstraciju algoritama obrade slike u medicinskim aplikacijama.
