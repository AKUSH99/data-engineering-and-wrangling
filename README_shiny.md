# IMDb vs. Rotten Tomatoes – Shiny Dashboard
## FHNW Datenprojekt

---

## Projektstruktur

```
files 2/
│
├── imdb_top_1000.csv              ← Datensatz 1 (bereits vorhanden)
├── rotten_tomatoes_movies.csv     ← Datensatz 2 (bereits vorhanden)
│
├── install_packages.R             ← SCHRITT 1: einmalig ausführen
├── pipeline.R                     ← Daten-Pipeline in R (tidyverse, ETL)
├── processed_data.rds             ← Generierter Datensatz nach ETL-Durchlauf
└── app.R                          ← SCHRITT 2: Shiny Dashboard starten (liest rds)
```

---

## Setup (einmalig)

### Schritt 1 – Packages installieren
In RStudio `install_packages.R` öffnen und auf **"Source"** klicken.

### Schritt 2 – Working Directory setzen
RStudio öffnet standardmässig im Home-Verzeichnis.
Sicherstellen dass das Working Directory stimmt:

```r
setwd("/Users/claudio/Data Engineering & Wrangling/files 2")
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
| Datenqualität | Transparente Quality Assurance und Missingness Reports |
| Datentabelle | Vollständiger Datensatz mit Filter und Suche |

---

## Hinweise

- Die **CSVs müssen im selben Ordner** liegen wie `pipeline.R` und `app.R`
- Beim ersten App-Start wird die Pipeline automatisch getriggert und als `processed_data.rds` gespeichert (ETL-Prinzip).
- Danach ist die Pipeline idempotente, das Dashboard startet schneller.
