# IMDb vs. Rotten Tomatoes – Der grosse Rating-Vergleich

**FHNW Modul: Data Engineering & Wrangling**

## Fragestellung

Wie unterscheiden sich die Bewertungen von Filmen auf **IMDb** (Publikumsbewertungen) und **Rotten Tomatoes** (Kritiker- und Publikumsbewertungen)? Welche Faktoren – Genre, Jahrzehnt, Popularität – beeinflussen die Abweichungen zwischen den Plattformen?

## Datenquellen

| Datensatz | Datei | Zeilen | Beschreibung |
|-----------|-------|--------|--------------|
| IMDb Top 1000 | `imdb_top_1000.csv` | ~1000 | Top-bewertete Filme auf IMDb (Titel, Rating, Votes, Genre) |
| Rotten Tomatoes | `rotten_tomatoes_movies.csv` | ~17'000 | Tomatometer, Audience Score, Kritikanzahl, Status |

Nach dem Inner Join über normalisierte Titel + Erscheinungsjahr bleiben **~618 gematchte Filme** für die Analyse.

> **Hinweis zum Selektionsbias:** Der IMDb-Datensatz enthält nur die Top 1000 Filme. Die Ergebnisse gelten daher für überdurchschnittlich gut bewertete Publikumsfilme, nicht für den Gesamtmarkt.

## Methodik / Pipeline

Die Datenverarbeitung erfolgt in einer **5-Schritt-Pipeline** (`pipeline.R`):

1. **Daten einlesen** – `read_csv()` mit gezielter Spaltenauswahl
2. **Datenbereinigung** – Nicht-numerische Jahreswerte entfernen, Titel normalisieren (lowercase, trimmed)
3. **Transformation & Merge** – Tomatometer von 0–100 auf 0–10 normalisieren, Inner Join, abgeleitete Variablen (Differenz, Genre, Dekade, Vote-Bucket)
4. **Qualitätsprüfung** – Automatische Checks auf Nullwerte, Duplikate, Wertebereiche
5. **Statistiken berechnen** – Korrelationen, Genre/Dekaden/Popularitäts-Aggregationen, Top-Abweichungen

## Dashboard

Das interaktive **Shiny Dashboard** (`app.R`) visualisiert die Ergebnisse in 7 Tabs:

| Tab | Inhalt |
|-----|--------|
| Übersicht | Verteilung, Scatter, Top-5-Abweichungen, Selektionsbias-Hinweis |
| Drei-Wege-Vergleich | IMDb vs. RT-Kritiker vs. RT-Publikum mit Korrelationen |
| Genre-Analyse | Bewertungen und Differenzen nach Genre (filterbar) |
| Zeittrend | Bewertungstrend nach Jahrzehnt (ab 1960er, n ≥ 48) |
| Popularität | IMDb-Votes vs. Bewertungsdifferenz |
| Zuverlässigkeit | Kritikanzahl, Tomatometer-Status, geflaggte Filme |
| Datentabelle | Vollständiger Datensatz mit Filter und Suche |

## Zentrale Ergebnisse

- **Publikum stimmt überein:** IMDb-Publikum und RT-Publikum korrelieren deutlich stärker als IMDb und RT-Kritiker
- **Kritiker weichen ab:** Die Korrelation zwischen IMDb (Publikum) und RT-Kritiker ist schwach
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
- **Shiny + shinydashboard** – Interaktives Web-Dashboard
- **plotly + ggplot2** – Interaktive Visualisierungen
- **DT** – Filterbare Datentabellen

## Projektstruktur

```
├── app.R                          ← Shiny Dashboard (UI + Server)
├── pipeline.R                     ← 5-Schritt Daten-Pipeline
├── install_packages.R             ← Einmalige Package-Installation
├── imdb_top_1000.csv              ← IMDb-Datensatz
├── rotten_tomatoes_movies.csv     ← Rotten-Tomatoes-Datensatz
└── README.md                      ← Diese Datei
```
