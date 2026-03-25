# IMDb vs. Rotten Tomatoes – Shiny Dashboard
## FHNW Datenprojekt

---

## Projektstruktur

```
├── imdb_top_1000.csv              ← Datensatz 1 (IMDb Top 1000)
├── rotten_tomatoes_movies.csv     ← Datensatz 2 (Rotten Tomatoes)
│
├── install_packages.R             ← SCHRITT 1: einmalig ausführen
├── pipeline.R                     ← Daten-Pipeline in R (tidyverse)
└── app.R                          ← SCHRITT 2: Shiny Dashboard starten
```

---

## Setup (einmalig)

### Schritt 1 – Packages installieren
In RStudio `install_packages.R` öffnen und auf **"Source"** klicken.

### Schritt 2 – Working Directory setzen
Sicherstellen dass das Working Directory auf den Projektordner zeigt:

```r
setwd("/Pfad/zum/Projekt")
```

Oder in RStudio: **Session → Set Working Directory → To Source File Location**

### Schritt 3 – App starten
`app.R` öffnen → **"Run App"** Button klicken (oben rechts im Editor).

---

## Dashboard Tabs

| Tab | Inhalt |
|-----|--------|
| Übersicht | Verteilung, Scatter, Top-Abweichungen, Selektionsbias-Hinweis |
| Drei-Wege-Vergleich | IMDb vs. RT-Kritiker vs. RT-Publikum (Korrelationen) |
| Genre-Analyse | Bewertungen und Differenzen nach Genre |
| Zeittrend | Bewertungstrend nach Jahrzehnt (ab 1960er) |
| Popularität | IMDb-Votes vs. Bewertungsdifferenz |
| Zuverlässigkeit | Kritikanzahl, tomatometer_status, geflaggte Filme |
| Datenqualität | Fehlende Werte, Duplikate, Match-Typen |
| Datentabelle | Vollständiger Datensatz mit Filter und Suche |

---

## Hinweise

- Die **CSVs müssen im selben Ordner** liegen wie `pipeline.R` und `app.R`
- Beim ersten Start werden die Daten automatisch durch `pipeline.R` geladen
- Alle Qualitätsprüfungen laufen automatisch beim App-Start (Konsole prüfen)
