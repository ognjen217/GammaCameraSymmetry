# GammaCameraSymmetry
Ovaj projekat je realizovan u okviru predmeta **Algoritmi obrade slike u automatici** i ima za cilj analizu simetrije snimaka gamma kamera korišćenjem algoritama obrade slike u MATLAB okruženju.

Autor: Ognjen Perić  
Broj indeksa: RA118/2021


## Opis projekta

Gamma kamere se koriste za medicinsku dijagnostiku, a simetrija snimka je važan parametar za procenu kvaliteta slike i ispravnost uređaja. Ovaj projekat implementira algoritme koji automatski analiziraju i kvantifikuju stepen simetrije u snimcima iz gamma kamera.

### Glavne funkcionalnosti

- **Učitavanje medicinskih slika gamma kamera u podržanim formatima**
- **Automatska detekcija simetrijskih osa** slike
- **Kvantitativna analiza simetrije** (npr. korišćenjem korelacije, razlike piksela, itd.)
- **Vizuelizacija rezultata** sa prikazom osa simetrije i grafičkim prikazom stepena simetrije
- **Generisanje izveštaja** o analizi simetrije

## Upotreba

1. Pokrenite MATLAB i otvorite ovaj projekat.
2. U glavnom skriptu (npr. `main.m` ili ekvivalent), podesite putanju do slike gamma kamere koju želite da analizirate.
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

## Primer pokretanja

```matlab
% Učitavanje slike
img = imread('data/sample_gamma_image.png');

% Analiza simetrije
[axis, score] = analyze_symmetry(img);

% Prikaz rezultata
show_symmetry(img, axis);
```

## Reference

Za više informacija o gamma kamerama i obradi slike:
- [Wikipedia: Gamma Camera](https://en.wikipedia.org/wiki/Gamma_camera)
- MATLAB dokumentacija: [Image Processing Toolbox](https://www.mathworks.com/products/image.html)

---

**Napomena:** Projekat je edukativnog karaktera i namenjen je za demonstraciju algoritama obrade slike u medicinskim aplikacijama.
