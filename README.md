# IMDb vs. Rotten Tomatoes – Der grosse Rating-Vergleich

**FHNW Modul: Data Engineering & Wrangling**

## Fragestellung

Wie unterscheiden sich die Bewertungen von Filmen auf **IMDb** (Publikumsbewertungen) und **Rotten Tomatoes** (Kritiker- und Publikumsbewertungen)? Welche Faktoren – Genre, Jahrzehnt, Popularität – beeinflussen die Abweichungen zwischen den Plattformen?

## Datenquellen

| Datensatz | Datei | Zeilen | Beschreibung |
|-----------|-------|--------|--------------|
| IMDb Top 1000 | `imdb_top_1000.csv` | ~1000 | Top-bewertete Filme auf IMDb (Titel, Rating, Votes, Genre) |
| Rotten Tomatoes | `rotten_tomatoes_movies.csv` | ~17'000 | Tomatometer, Audience Score, Kritikanzahl, Status |

Nach einem zweistufigen Matching (exakter Join + Fuzzy Matching mit Jaro-Winkler-Distanz) bleiben **641 gematchte Filme** für die Analyse.

> **Hinweis zum Selektionsbias:** Der IMDb-Datensatz enthält nur die Top 1000 Filme. Die Ergebnisse gelten daher für überdurchschnittlich gut bewertete Publikumsfilme, nicht für den Gesamtmarkt.

## Methodik / Pipeline

Die Datenverarbeitung erfolgt in einer **5-Schritt-Pipeline** (`pipeline.R`):

1. **Daten einlesen** – `read_csv()` mit gezielter Spaltenauswahl
2. **Datenbereinigung** – Nicht-numerische Jahreswerte entfernen, Titel normalisieren (lowercase, trimmed)
3. **Transformation & Merge** – Tomatometer von 0–100 auf 0–10 normalisieren, exakter Join + Fuzzy Matching (Jaro-Winkler), abgeleitete Variablen (Differenz, Genre, Dekade, Vote-Bucket)
4. **Qualitätsprüfung** – Automatische Checks auf Nullwerte, Duplikate, Wertebereiche
5. **Statistiken berechnen** – Korrelationen mit Konfidenzintervallen (`cor.test`), t-Test, Cohen's d, Genre/Dekaden/Popularitäts-Aggregationen, Top-Abweichungen

## Dashboard

Das interaktive **Shiny Dashboard** (`app.R`) visualisiert die Ergebnisse in 8 Tabs:

| Tab | Inhalt |
|-----|--------|
| Übersicht | Verteilung, Scatter, Top-5-Abweichungen, Selektionsbias-Hinweis |
| Drei-Wege-Vergleich | IMDb vs. RT-Kritiker vs. RT-Publikum mit Korrelationen |
| Genre-Analyse | Bewertungen und Differenzen nach Genre (filterbar) |
| Zeittrend | Bewertungstrend nach Jahrzehnt (ab 1960er, n ≥ 48) |
| Popularität | IMDb-Votes vs. Bewertungsdifferenz |
| Zuverlässigkeit | Kritikanzahl, Tomatometer-Status, geflaggte Filme |
| Datenqualität | Fehlende Werte, Duplikate, Match-Typen |
| Datentabelle | Vollständiger Datensatz mit Filter und Suche |

## Zentrale Ergebnisse

- **Publikum stimmt überein:** IMDb-Publikum und RT-Publikum korrelieren mit r = 0.489 (95% KI [0.427, 0.545])
- **Kritiker weichen ab:** Die Korrelation zwischen IMDb (Publikum) und RT-Kritiker beträgt nur r = 0.227
- **Signifikante Differenz:** Kritiker bewerten im Schnitt 0.9 Punkte höher (t = −22.06, p < 0.001, Cohen's d = −0.87)
- **Genre-Unterschiede:** Genres wie Animation und Biography zeigen die grössten Plattform-Differenzen
- **Popularität:** Hochpopuläre Filme (>1M Votes) haben tendenziell kleinere Bewertungslücken

## Setup & Ausführung

### Voraussetzungen
- **R** (≥ 4.0) und optional **RStudio**

### Schritte

```r
# 1. Packages installieren (einmalig)
source("install_packages.R")

# 2. App starten
shiny::runApp("app.R")
```

Alternativ in RStudio: `app.R` öffnen → **Run App** klicken.

## Technologien

- **R** mit tidyverse (dplyr, readr, tidyr, stringr)
- **stringdist** – Fuzzy Matching (Jaro-Winkler-Distanz)
- **Shiny + shinydashboard** – Interaktives Web-Dashboard
- **plotly + ggplot2** – Interaktive Visualisierungen
- **DT** – Filterbare Datentabellen

## Projektstruktur

```
├── app.R                          ← Shiny Dashboard (UI + Server)
├── pipeline.R                     ← 5-Schritt Daten-Pipeline
├── install_packages.R             ← Einmalige Package-Installation
├── versions.txt                   ← Package-Versionen für Reproduzierbarkeit
├── imdb_top_1000.csv              ← IMDb-Datensatz
├── rotten_tomatoes_movies.csv     ← Rotten-Tomatoes-Datensatz
├── Projektbericht.md              ← Wissenschaftlicher Projektbericht
└── README.md                      ← Diese Datei
```
