# Projektbericht: IMDb vs. Rotten Tomatoes – Der grosse Rating-Vergleich

**Modul:** Data Engineering & Wrangling | FHNW  
**Autoren:** Almidin Bangoji, Claudio Vinci  
**Datum:** März 2026

---

## Abstract

Diese Arbeit untersucht die Bewertungsunterschiede zwischen **IMDb** (Publikumsbewertungen) und **Rotten Tomatoes** (Kritiker- und Publikumsbewertungen). Aus 1'000 IMDb-Top-Filmen und 17'712 Rotten-Tomatoes-Einträgen wurden durch einen Inner Join 618 gemeinsame Filme identifiziert. Die Analyse zeigt, dass die Publikumsmeinungen beider Plattformen deutlich stärker übereinstimmen (r = 0.541) als die Bewertungen von IMDb-Publikum und RT-Kritikern (r = 0.222). Kritiker bewerten die gleichen Filme im Schnitt 0.9 Punkte höher als das IMDb-Publikum. Diese Ergebnisse gelten spezifisch für den Bereich der Top-bewerteten Filme und sind durch den Selektionsbias des IMDb-Datensatzes eingeschränkt.

---

## 1. Einleitung

### 1.1 Ausgangslage

Filmbewertungen beeinflussen massgeblich, welche Filme ein breites Publikum erreichen. Zwei der grössten Bewertungsplattformen – **IMDb** und **Rotten Tomatoes** – verfolgen dabei unterschiedliche Ansätze:

- **IMDb** aggregiert Publikumsbewertungen auf einer Skala von 1–10
- **Rotten Tomatoes** unterscheidet zwischen dem **Tomatometer** (Anteil positiver Kritiker-Reviews, 0–100%) und einem **Audience Score** (Publikumsbewertung)

### 1.2 Fragestellung

1. Wie stark korrelieren die Bewertungen zwischen IMDb und Rotten Tomatoes?
2. Gibt es systematische Abweichungen zwischen Publikum und Kritikern?
3. Welche Faktoren (Genre, Jahrzehnt, Popularität) beeinflussen die Bewertungsunterschiede?
4. Wie zuverlässig sind die Rotten-Tomatoes-Bewertungen bei geringer Kritikanzahl?

### 1.3 Selektionsbias

Ein zentraler Punkt ist der **Selektionsbias**: Der IMDb-Datensatz enthält nur die Top 1'000 Filme. Die IMDb-Ratings liegen daher zwischen 7.6 und 9.3 (nicht 1–10). Dies bedeutet, dass unsere Ergebnisse das Bewertungsverhalten für **überdurchschnittlich gut bewertete** Filme beschreiben, nicht für den gesamten Filmmarkt. 59.1% der analysierten Filme haben einen Tomatometer-Wert ≥ 90%.

---

## 2. Datenquellen

| Eigenschaft | IMDb Top 1000 | Rotten Tomatoes |
|-------------|---------------|-----------------|
| Datei | `imdb_top_1000.csv` | `rotten_tomatoes_movies.csv` |
| Zeilen (roh) | 1'000 | 17'712 |
| Fehlende Werte (roh) | 157 | 1'613 |
| Genutzte Spalten | Series_Title, Released_Year, Genre, IMDB_Rating, No_of_Votes, Meta_score | movie_title, original_release_date, genres, tomatometer_rating, audience_rating, tomatometer_count, tomatometer_status |
| Bewertungsskala | 1–10 (numerisch) | 0–100% (Tomatometer), 0–100 (Audience) |

---

## 3. Methodik

### 3.1 Technologien

- **R 4.5** als Programmiersprache
- **tidyverse** (dplyr, readr, tidyr, stringr) für Datenmanipulation
- **Shiny + shinydashboard** für das interaktive Web-Dashboard
- **plotly + ggplot2** für interaktive Visualisierungen
- **DT** für filterbare Datentabellen

### 3.2 Daten-Pipeline

Die gesamte Datenverarbeitung erfolgt in einer reproduzierbaren **5-Schritt-Pipeline** (`pipeline.R`), die beim Start des Dashboards automatisch ausgeführt wird. Jeder Schritt gibt Statusmeldungen aus, sodass der Fortschritt nachvollziehbar ist.

#### Schritt 1: Daten einlesen

Die zwei CSV-Dateien werden mit `readr::read_csv()` eingelesen. Bevor die Dateien geladen werden, prüft die Pipeline deren Existenz und gibt eine klare Fehlermeldung falls eine Datei fehlt. Nur die für die Analyse relevanten Spalten werden selektiert.

**Ergebnis:** IMDb: 1'000 Zeilen | RT: 17'712 Zeilen

#### Schritt 2: Datenbereinigung

- **IMDb:** Die Spalte `Released_Year` enthält vereinzelt nicht-numerische Werte (z.B. "PG"). Diese werden über `as.integer(as.numeric())` in NA konvertiert und anschliessend entfernt. Ergebnis: 999 Zeilen (1 entfernt).
- **Rotten Tomatoes:** Filme ohne Tomatometer-Rating oder Titel werden entfernt. Das Erscheinungsjahr wird aus dem Datum extrahiert. Ergebnis: 17'668 Zeilen (44 entfernt).
- **Beide:** Filmtitel werden für den späteren Join normalisiert: Kleinbuchstaben, Leerzeichen getrimmt.

#### Schritt 3: Transformation & Merge

- **Skalen-Normalisierung:** Der Tomatometer (0–100) und Audience Score (0–100) werden durch 10 dividiert, um sie auf die IMDb-Skala (0–10) zu bringen. Ohne diesen Schritt wären Differenzberechnungen nicht sinnvoll.
- **Inner Join:** Die Datensätze werden über normalisierten Titel + Erscheinungsjahr zusammengeführt. Nur Filme, die auf beiden Plattformen existieren, bleiben erhalten.
- **Abgeleitete Variablen:**
  - `rating_diff` = IMDb-Rating − Tomatometer (normalisiert)
  - `primary_genre` = Erstes Genre jedes Films
  - `decade` = Jahrzehnt des Erscheinungsjahres
  - `vote_bucket` = Kategorisierung nach Stimmenzahl (<100k, 100k–500k, 500k–1M, >1M)
  - `low_critic_count` = Flag für Filme mit weniger als 20 Kritikerbesprechungen

**Ergebnis:** 618 gematchte Filme

#### Schritt 4: Qualitätsprüfung

Automatische Validierung des gemergten Datensatzes:
- Keine fehlenden Werte in `IMDB_Rating` und `tomatometer_normalized` ✓
- Keine Duplikate (gleicher Titel + Jahr) ✓
- IMDb-Ratings im erwarteten Bereich (7.6 – 9.3) ✓
- Tomatometer im erwarteten Bereich (2.6 – 10.0) ✓
- 9 Filme mit weniger als 20 Kritikerbesprechungen → geflaggt

Bei Verstössen bricht die Pipeline mit einer Fehlermeldung ab (`stopifnot`).

#### Schritt 5: Statistiken berechnen

- Pearson-Korrelationen zwischen allen drei Bewertungsdimensionen
- Genre-Aggregation (nur Genres mit n ≥ 5 Filmen)
- Dekaden-Aggregation (nur Dekaden mit n ≥ 48 Filmen – dem Wert der kleinsten repräsentativen Dekade)
- Vote-Bucket-Aggregation
- Tomatometer-Status-Aggregation
- Top-5-Listen der grössten positiven und negativen Abweichungen

### 3.3 Dashboard-Entwicklung

Das Ergebnis wird als **Shiny Dashboard** mit 7 thematischen Tabs präsentiert. Alle Visualisierungen sind interaktiv (Hover-Tooltips, Zoom, Filter). Das Dashboard nutzt ein dunkles Farbschema (Dark Theme) mit einheitlichen Farben:
- Gold (#F5C518) für IMDb
- Rot (#FA320A) für RT-Kritiker
- Blau (#4A90D9) für RT-Publikum

---

## 4. Ergebnisse

### 4.1 Korrelationsanalyse (Kernbefund)

| Vergleich | Pearson r | Interpretation |
|-----------|-----------|----------------|
| IMDb (Publikum) vs. RT-Kritiker | **0.222** | Schwache Korrelation |
| IMDb (Publikum) vs. RT-Publikum | **0.541** | Moderate bis starke Korrelation |
| RT-Kritiker vs. RT-Publikum | **0.333** | Schwache bis moderate Korrelation |

**Zentrales Ergebnis:** Die Publikumsmeinungen auf IMDb und Rotten Tomatoes stimmen deutlich stärker überein (r = 0.541) als die Bewertungen zwischen Publikum und Kritikern (r = 0.222). Kritiker und Publikum bewerten Filme offenbar nach unterschiedlichen Massstäben.

### 4.2 Systematische Abweichung

Die durchschnittliche Differenz (IMDb − Tomatometer normalisiert) beträgt **−0.913 Punkte**. Das heisst: RT-Kritiker bewerten die gleichen Filme im Schnitt fast einen ganzen Punkt höher als das IMDb-Publikum. Bei einem Datensatz aus ausschliesslich Top-bewerteten Filmen bewerten die Kritiker also noch positiver als das Publikum.

### 4.3 Grösste Abweichungen

**IMDb bewertet deutlich höher als RT-Kritiker:**

| Film | Jahr | IMDb | RT (norm.) | Differenz |
|------|------|------|------------|-----------|
| The Boondock Saints | 1999 | 7.8 | 2.8 | +5.0 |
| Seven Pounds | 2008 | 7.6 | 2.6 | +5.0 |
| The Butterfly Effect | 2004 | 7.6 | 3.3 | +4.3 |
| I Am Sam | 2001 | 7.7 | 3.5 | +4.2 |
| Man on Fire | 2004 | 7.7 | 3.8 | +3.9 |

**RT-Kritiker bewerten deutlich höher als IMDb:**

| Film | Jahr | IMDb | RT (norm.) | Differenz |
|------|------|------|------------|-----------|
| Love and Death | 1975 | 7.7 | 10.0 | −2.3 |
| The Taking of Pelham 123 | 1974 | 7.7 | 10.0 | −2.3 |
| Cape Fear | 1962 | 7.7 | 10.0 | −2.3 |
| The Ladykillers | 1955 | 7.7 | 10.0 | −2.3 |
| A Hard Day's Night | 1964 | 7.6 | 9.8 | −2.2 |

Auffällig: Filme, bei denen das Publikum die Kritiker übertrifft (bis +5.0), zeigen grössere Extremwerte als umgekehrt (maximal −2.3). Dies liegt am Selektionsbias: IMDb-Ratings starten bei 7.6, sodass der maximale negative Ausschlag begrenzt ist.

### 4.4 Genre-Analyse

9 Genres haben mindestens 5 Filme im Datensatz:

| Genre | Ø IMDb | Ø RT-Kritiker | Ø Differenz | Anzahl |
|-------|--------|---------------|-------------|--------|
| Animation | 7.92 | 9.29 | −1.38 | 45 |
| Comedy | 7.88 | 8.98 | −1.10 | 99 |
| Drama | 7.95 | 8.91 | −0.96 | 157 |
| Horror | 7.92 | 8.79 | −0.87 | 10 |
| Crime | 8.02 | 8.86 | −0.84 | 62 |
| Adventure | 7.94 | 8.72 | −0.78 | 58 |
| Biography | 7.92 | 8.66 | −0.74 | 71 |
| Action | 7.93 | 8.61 | −0.69 | 102 |
| Mystery | 8.04 | 8.41 | −0.37 | 7 |

**Insight:** Die grössten Diskrepanzen zeigen sich bei **Animation** (−1.38) und **Comedy** (−1.10). Hier bewerten Kritiker die Filme deutlich positiver als das IMDb-Publikum. Bei **Mystery** (−0.37) und **Action** (−0.69) sind sich Publikum und Kritiker am nächsten.

### 4.5 Zeittrend (Dekaden-Analyse)

| Dekade | Ø IMDb | Ø RT-Kritiker | Filme |
|--------|--------|---------------|-------|
| 1960er | 7.93 | 9.23 | 48 |
| 1970er | 7.94 | 9.30 | 51 |
| 1980er | 7.96 | 8.89 | 60 |
| 1990er | 7.97 | 8.62 | 101 |
| 2000er | 7.90 | 8.15 | 133 |
| 2010er | 7.89 | 8.88 | 138 |

**Insight:** Die IMDb-Ratings bleiben über die Jahrzehnte relativ stabil (~7.9). Die Kritikerbewertungen zeigen dagegen mehr Variation: In den 1970ern erreichen sie den Höchstwert (9.30), fallen dann in den 2000ern auf 8.15 und steigen in den 2010ern wieder auf 8.88. Ältere Filme werden von Kritikern tendenziell höher bewertet – möglicherweise ein Survivorship-Effekt: Nur Klassiker überdauern.

Dekaden vor den 1960ern wurden ausgeblendet (weniger als 48 Filme), da einzelne Klassiker wie Chaplin oder Metropolis nicht repräsentativ für ihre Epoche sind.

### 4.6 Popularitätsanalyse

| Vote-Bucket | Ø IMDb | Ø Differenz | Filme |
|-------------|--------|-------------|-------|
| <100k | 7.84 | −1.29 | 175 |
| 100k–500k | 7.88 | −0.79 | 290 |
| 500k–1M | 8.05 | −0.88 | 118 |
| >1M | 8.55 | −0.15 | 35 |

**Insight:** Hochpopuläre Filme (>1M Votes) haben die kleinste Bewertungslücke (−0.15) und das höchste Durchschnittsrating (8.55). Bei diesen Blockbustern stimmen Publikum und Kritiker fast überein. Weniger bekannte Filme (<100k Votes) zeigen die grösste Diskrepanz (−1.29).

### 4.7 Zuverlässigkeit

- **Median Kritikanzahl:** 89 Besprechungen pro Film
- **Certified-Fresh Filme:** 512 von 618 (82.8%)
- **Filme mit <20 Kritiken:** 9 Filme (geflaggt als potenziell unzuverlässig)

Die Tomatometer-Status-Analyse zeigt:

| Status | Ø IMDb | Ø Differenz | Filme |
|--------|--------|-------------|-------|
| Certified-Fresh | 7.96 | −1.12 | 512 |
| Fresh | 7.86 | −0.34 | 93 |
| Rotten | 7.66 | +3.17 | 13 |

**Insight:** Die 13 "Rotten"-Filme zeigen eine extreme Diskrepanz: Vom IMDb-Publikum mit 7.66 bewertet (Top-1000-würdig), aber von Kritikern als schlecht eingestuft. Dies sind typische "Publikumslieblinge", die bei Kritikern durchfallen (z.B. The Boondock Saints).

---

## 5. Diskussion

### 5.1 Interpretation der Ergebnisse

Die Analyse bestätigt die Hypothese, dass **Publikum und Kritiker Filme unterschiedlich bewerten**. Die schwache Korrelation (r = 0.222) zwischen IMDb und RT-Kritikern zeigt, dass professionelle Filmkritik anderen Massstäben folgt als die kollektive Publikumsmeinung.

Gleichzeitig zeigt die moderate Korrelation (r = 0.541) zwischen den Publikumsbewertungen beider Plattformen, dass die "Stimme des Publikums" **plattformübergreifend konsistent** ist. Egal ob auf IMDb oder Rotten Tomatoes – Zuschauer bewerten ähnlich.

### 5.2 Limitationen

1. **Selektionsbias:** Der IMDb-Datensatz enthält nur die Top 1'000 Filme (Ratings 7.6–9.3). Die Ergebnisse sind nicht auf durchschnittliche oder schlecht bewertete Filme übertragbar.

2. **Matching-Verlust:** Von 1'000 IMDb-Filmen konnten nur 618 mit RT-Einträgen gematcht werden. Das Matching basiert auf exakter Titel+Jahr-Übereinstimmung – bei alternativen Titeln oder Tippfehlern geht der Match verloren. Fuzzy Matching könnte die Trefferquote verbessern.

3. **Genre-Vereinfachung:** Es wird nur das erste Genre pro Film genutzt. Filme mit mehreren Genres (z.B. "Action, Sci-Fi") werden nur dem ersten zugeordnet.

4. **Zeitliche Verzerrung:** Ältere Filme im Datensatz sind per Definition "Klassiker" (Survivorship Bias). Die hohen Kritikerbewertungen der 1960er/70er spiegeln nicht die durchschnittliche Filmqualität jener Epoche wider.

### 5.3 Mögliche Erweiterungen

- Fuzzy Matching (z.B. mit `stringdist`) für eine höhere Match-Rate
- Sentimentanalyse von Review-Texten
- Vergleich mit weiteren Plattformen (Metacritic, Letterboxd)
- Zeitreihenanalyse: Wie verändern sich Ratings eines Films über die Jahre?

---

## 6. Fazit

Unsere Analyse von 618 Filmen zeigt drei zentrale Erkenntnisse:

1. **Publikum ist sich einig:** IMDb- und RT-Publikumsbewertungen korrelieren mit r = 0.541 – die "Stimme des Publikums" ist plattformübergreifend konsistent.

2. **Kritiker weichen ab:** Die Korrelation zwischen IMDb-Publikum und RT-Kritikern ist mit r = 0.222 schwach. Kritiker bewerten die gleichen Top-Filme im Schnitt 0.9 Punkte höher.

3. **Genre und Popularität spielen eine Rolle:** Animation und Comedy zeigen die grössten Abweichungen. Hochpopuläre Filme (>1M Votes) haben fast keine Lücke zwischen Publikum und Kritikern.

Das Projekt demonstriert einen vollständigen **Data-Engineering-Workflow**: vom Einlesen heterogener Rohdaten über Bereinigung, Transformation und Qualitätssicherung bis hin zur interaktiven Visualisierung in einem Dashboard.

---

## 7. Reproduzierbarkeit

Das gesamte Projekt ist reproduzierbar:

```r
# Packages installieren (einmalig)
source("install_packages.R")

# Dashboard starten (Pipeline läuft automatisch)
shiny::runApp("app.R")
```

Die Pipeline gibt bei jedem Start detaillierte Statusmeldungen aus:
```
[1] DATEN EINGELESEN – IMDb: 1000 Zeilen | RT: 17712 Zeilen
[2] NACH DATENBEREINIGUNG – IMDb: 999 | RT: 17668
[3] NACH DATENTRANSFORMATION – 618 gematchte Filme
[4] QUALITÄTSPRÜFUNG – ✓ Alle Prüfungen bestanden
[5] ANALYSE-ERGEBNISSE – r(IMDb, RT-Kritiker): 0.222
✓ Pipeline vollständig abgeschlossen.
```

---

## Anhang: Projektstruktur

| Datei | Zweck | Zeilen |
|-------|-------|--------|
| `pipeline.R` | 5-Schritt-Daten-Pipeline | ~280 |
| `app.R` | Shiny Dashboard (UI + Server) | ~700 |
| `install_packages.R` | Einmalige Package-Installation | ~35 |
| `imdb_top_1000.csv` | IMDb-Rohdaten | 1'000 |
| `rotten_tomatoes_movies.csv` | RT-Rohdaten | 17'712 |
| `README.md` | Projekt-Dokumentation | – |
| `Projektbericht.md` | Dieser Bericht | – |
