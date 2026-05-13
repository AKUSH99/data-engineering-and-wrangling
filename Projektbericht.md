# Projektbericht: IMDb vs. Rotten Tomatoes – Der grosse Rating-Vergleich

**Modul:** Data Engineering & Wrangling | FHNW
**Autoren:** Almidin Bangoji, Claudio Vinci
**Datum:** Mai 2026
**Repo:** [github.com/AKUSH99/data-engineering-and-wrangling](https://github.com/AKUSH99/data-engineering-and-wrangling)

---

## Abstract

Diese Arbeit untersucht die Bewertungsunterschiede zwischen **IMDb** (Publikumsbewertungen) und **Rotten Tomatoes** (Kritiker- und Publikumsbewertungen). Aus 1'000 IMDb-Top-Filmen und 17'712 Rotten-Tomatoes-Einträgen wurden durch exakten Titelabgleich (630 Filme) und Fuzzy Matching mit Jaro-Winkler-Distanz (14 weitere Filme) insgesamt **644 gemeinsame Filme** identifiziert.

Die Analyse zeigt, dass die Publikumsmeinungen beider Plattformen deutlich stärker übereinstimmen (r = 0.489, 95% KI [0.427, 0.545]) als die Bewertungen von IMDb-Publikum und RT-Kritikern (r = 0.228, 95% KI [0.154, 0.300]). Kritiker bewerten die gleichen Filme im Schnitt 0.9 Punkte höher als das IMDb-Publikum – ein statistisch hochsignifikanter Unterschied (t = −22.22, p < 0.001, Cohen's d = −0.88). Die grösste Divergenz zeigt sich bei Animation und Comedy, die kleinste bei hochpopulären Blockbustern mit über einer Million Bewertungen.

Sämtliche Analysen und Visualisierungen wurden in einem interaktiven Shiny Dashboard mit 8 thematischen Tabs umgesetzt. Der vorliegende Bericht enthält Screenshots aller Tabs und ist ohne Ausführung von Code vollständig nachvollziehbar.

---

## 1. Einleitung

### 1.1 Ausgangslage

Filmbewertungen beeinflussen massgeblich, welche Filme ein breites Publikum erreichen. Die zwei grössten Bewertungsplattformen – **IMDb** und **Rotten Tomatoes** – verfolgen dabei unterschiedliche Ansätze:

- **IMDb** aggregiert Publikumsbewertungen auf einer Skala von 1–10
- **Rotten Tomatoes** unterscheidet zwischen dem **Tomatometer** (Anteil positiver Kritiker-Reviews, 0–100%) und einem **Audience Score** (Publikumsbewertung)

### 1.2 Fragestellung

1. Wie stark korrelieren die Bewertungen zwischen IMDb und Rotten Tomatoes?
2. Gibt es systematische Abweichungen zwischen Publikum und Kritikern?
3. Welche Faktoren (Genre, Jahrzehnt, Popularität) beeinflussen die Bewertungsunterschiede?
4. Wie zuverlässig sind die Rotten-Tomatoes-Bewertungen bei geringer Kritikanzahl?

### 1.3 Selektionsbias

Ein zentraler Punkt ist der **Selektionsbias**: Der IMDb-Datensatz enthält nur die Top 1'000 Filme. Die IMDb-Ratings liegen daher zwischen 7.6 und 9.3 (nicht 1–10). Die Ergebnisse beschreiben somit das Bewertungsverhalten für **überdurchschnittlich gut bewertete** Filme, nicht für den gesamten Filmmarkt. 59% der analysierten Filme haben einen Tomatometer-Wert ≥ 90%.

---

## 2. Datenquellen

| Eigenschaft | IMDb Top 1000 | Rotten Tomatoes |
|:------------|:--------------|:----------------|
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
- **stringdist** für Fuzzy Matching (Jaro-Winkler-Distanz)
- **Shiny + shinydashboard** für das interaktive Web-Dashboard
- **plotly + ggplot2** für interaktive Visualisierungen
- **DT** für filterbare Datentabellen

### 3.2 Daten-Pipeline

Die gesamte Datenverarbeitung erfolgt in einer reproduzierbaren **5-Schritt-Pipeline** (`pipeline.R`), die beim Start des Dashboards automatisch ausgeführt wird. Jeder Schritt gibt Statusmeldungen aus, sodass der Fortschritt nachvollziehbar ist.

#### Schritt 1: Daten einlesen

Die zwei CSV-Dateien werden mit `readr::read_csv()` eingelesen. Vor dem Laden prüft die Pipeline deren Existenz und gibt bei Fehlen eine klare Fehlermeldung aus. Nur die für die Analyse relevanten Spalten werden selektiert.

**Ergebnis:** IMDb: 1'000 Zeilen | RT: 17'712 Zeilen

#### Schritt 2: Datenbereinigung und Regular Expressions

- **IMDb:** Die Spalte `Released_Year` enthält vereinzelt nicht-numerische Werte (z.B. "PG"). Diese werden über `as.integer(as.numeric())` in NA konvertiert und anschliessend entfernt. Ergebnis: 999 Zeilen (1 entfernt).
- **Rotten Tomatoes:** Filme ohne Tomatometer-Rating oder Titel werden entfernt. Das Erscheinungsjahr wird aus dem Datum extrahiert. Ergebnis: 17'668 Zeilen (44 entfernt).
- **Beide (Regex-Einsatz):** Filmtitel werden für den Join mit **Regular Expressions** normalisiert: Kleinbuchstaben, Trimmen, Entfernen der Artikel ("the", "a", "an") am Anfang, Bereinigung von Sonderzeichen (`[[:punct:]]`), Entfernen redundanter Leerzeichen via `str_squish()`.

#### Schritt 3: Transformation & Merge

- **Skalen-Normalisierung:** Tomatometer (0–100) und Audience Score (0–100) werden durch 10 dividiert, um sie auf die IMDb-Skala (0–10) zu bringen.
- **Zwei-Stufen-Matching:**
  1. **Exakter Join** über normalisierten Titel + Erscheinungsjahr → 630 Treffer
  2. **Fuzzy Matching** (Jaro-Winkler-Distanz, Schwelle < 0.12) für nicht-gematchte Filme mit gleichem Erscheinungsjahr → 14 zusätzliche Treffer. Dies fängt Titelabweichungen wie Tippfehler, Sonderzeichen oder Untertitel-Varianten ab.
- **Abgeleitete Variablen:** `rating_diff` (IMDb − Tomatometer normalisiert), `primary_genre` (erstes Genre via `str_split_fixed`), `decade` (Jahrzehnt), `vote_bucket` (Kategorisierung nach Stimmenzahl: <100k, 100k–500k, 500k–1M, >1M), `low_critic_count` (Flag für < 20 Kritikerbesprechungen).

**Ergebnis:** 644 gematchte Filme (630 exakt + 14 fuzzy)

#### Schritt 4: Qualitätsprüfung

Automatische Validierung des gemergten Datensatzes: Keine fehlenden Werte in Kernspalten ✓, keine Duplikate (Titel + Jahr) ✓, IMDb-Ratings im erwarteten Bereich (7.6–9.3) ✓, Tomatometer im erwarteten Bereich (2.6–10.0) ✓. 9 Filme mit weniger als 20 Kritikerbesprechungen werden als potenziell unzuverlässig geflaggt. Bei Verstössen bricht die Pipeline via `stopifnot()` ab.

#### Schritt 5: Statistiken berechnen

- Pearson-Korrelationen zwischen allen drei Bewertungsdimensionen **mit 95%-Konfidenzintervallen** (`cor.test()`)
- **Einstichproben-t-Test** (H₀: Ø Differenz = 0) mit Effektstärke (Cohen's d)
- Genre-Aggregation (nur Genres mit n ≥ 5 Filmen)
- Dekaden-Aggregation (nur Dekaden mit n ≥ 48 Filmen – dem Wert der kleinsten repräsentativen Dekade)
- Vote-Bucket- und Tomatometer-Status-Aggregation
- Top-5-Listen der grössten positiven und negativen Abweichungen

### 3.3 Dashboard-Entwicklung

Das Ergebnis wird als **Shiny Dashboard** mit **8 thematischen Tabs** präsentiert. Alle Visualisierungen sind interaktiv (Hover-Tooltips, Zoom, Filter). Das Dashboard nutzt ein durchgängiges **Dark Theme** mit einheitlicher Farbcodierung:

- **Gold (#F5C518)** für IMDb-Daten
- **Rot (#FA320A)** für RT-Kritiker-Daten
- **Blau (#4A90D9)** für RT-Publikums-Daten

Diese drei Farben ziehen sich konsistent durch alle Plots, Legenden, ValueBoxes und Tabellen, sodass die Zuordnung auf jeder Seite sofort erkennbar ist.

Im Folgenden wird jeder Tab mit Screenshot und Beschreibung dokumentiert.

---

#### Tab 1: Übersicht – Kernbefunde auf einen Blick

![[01_Uebersicht.png]]

Der Einstiegs-Tab gibt einen kompakten Gesamtüberblick über den Datensatz. Oben drei gestylte Kernbefund-Karten mit farbigen Seitenrändern: Blau markiert den Publikum-Konsens (r = 0.49, „IMDb- und RT-Publikum stimmen plattformübergreifend überein"), Rot die Kritiker-Abweichung (Δ 0.9 Punkte, Cohen's d = −0.88), Gold die Kontext-Faktoren (644 Filme, „Animation & Comedy zeigen die grössten Differenzen; Filme mit > 1 Mio. Votes fast ohne Lücke").

Darunter vier ValueBoxen: 644 analysierte Filme, Pearson r = 0.228 (IMDb vs. RT-Kritiker), Ø Differenz −0.912 und Selektionsbias-Hinweis „Top 1000". In der nächsten Zeile links zwei nebeneinander angeordnete Histogramme (ggplot2-Subplot): Das linke zeigt die IMDb-Verteilung (Gold, x-Achse 0–10, y-Achse 0–400), das rechte den Tomatometer (Rot, x-Achse 0–10, y-Achse 0–200). Gestrichelte weisse Linien markieren den jeweiligen Mittelwert. Die rote RT-Verteilung ist deutlich breiter und weiter rechts zentriert.

Rechts daneben eine Infobox zum Selektionsbias: „IMDb-Ratings: 7.6 – 9.3 (nicht 1–10)", „RT-Scores hoch, weil Top-1000-Filme auch von Kritikern überdurchschnittlich bewertet werden", „59% der Filme haben Tomatometer ≥ 90%". In der unteren Zeile links ein Scatterplot (Tomatometer auf x-Achse 0–10, IMDb auf y-Achse 8.0–9.0) mit gestrichelter roter Diagonalen und weisser Regressionslinie. Annotationen: „Pearson r = 0.228", „85% unter Diagonale: RT-Kritiker > IMDb", „15% darüber: IMDb > RT-Kritiker". Rechts daneben zwei Tab-Panels („IMDb >> RT" und „RT >> IMDb") mit den fünf grössten Abweichungen als interaktive DT-Tabellen.

---

#### Tab 2: Drei-Wege-Vergleich – Publikum vs. Kritiker vs. Publikum

![[02_Drei_Wege_Vergleich.png]]

Dieser Tab erweitert die Analyse um die dritte Bewertungsdimension: den RT-Audience-Score (Publikumsbewertung auf Rotten Tomatoes). Oben drei InfoBoxen mit den paarweisen Korrelationen und automatischen Labels: IMDb vs. RT-Kritiker (r = 0.228, „schwache Korrelation"), IMDb vs. RT-Publikum (r = 0.49, „mittlere Korrelation"), RT-Kritiker vs. RT-Publikum (r = 0.371, „schwache Korrelation").

Darunter drei nebeneinander angeordnete Scatterplots (gemeinsame y-Achse: IMDb 0–10): Links IMDb vs. RT-Kritiker (Gold-Punkte, Annotation r = 0.228), Mitte IMDb vs. RT-Publikum (Blau-Punkte, r = 0.49), Rechts RT-Kritiker vs. RT-Publikum (Rot-Punkte, r = 0.371). Die Publikums-Punkte (Mitte und rechts) liegen enger beieinander als die Kritiker-Punkte (links).

Unten links ein horizontales Balkendiagramm der Ø-Differenzen: IMDb − RT-Kritiker (−0.91), IMDb − RT-Publikum (−0.92), RT-Kritiker − RT-Publikum (−0.01). Unten rechts eine Interpretationsbox mit den statistischen Kennzahlen: r-Werte mit 95%-KI und p-Werten, t-Test (t = −22.22, p < 0.001, Cohen's d = −0.88) und dem Fazit: „Publikumsmeinungen konvergieren plattformübergreifend. Kritikerurteile weichen systematisch ab."

---

#### Tab 3: Genre-Analyse – Wo gehen die Meinungen auseinander?

![[03_Genre_Analyse.png]]

Oben ein Filter-Box mit SelectizeInput (9 Genres: Action, Adventure, Animation, Biography, Comedy, Crime, Drama, Horror, Mystery – alle standardmässig aktiv). Darunter ein Grouped Bar Chart (y-Achse 6.5–10) mit drei Balken pro Genre: Gold = IMDb, Rot = RT-Kritiker, Blau = RT-Publikum. Die Genres sind nach Ø IMDb-Rating sortiert.

Darunter ein horizontales Balkendiagramm der Ø-Bewertungsdifferenz (IMDb − Tomatometer). Die Werte stehen als Textlabels neben den Balken: Animation (n=46, −1.37), Comedy (n=106, −1.11), Drama (n=165, −0.97), Horror (n=10, −0.87), Crime (n=65, −0.83), Adventure (n=60, −0.78), Biography (n=71, −0.74), Action (n=106, −0.65), Mystery (n=7, −0.37). Eine Annotation „Grösste Plattform-Differenz" markiert Animation mit Pfeil.

---

#### Tab 4: Zeittrend – Bewertungen über die Jahrzehnte

![[04_Zeittrend.png]]

Ein Liniendiagramm über sechs Jahrzehnte (1960er bis 2010er, y-Achse 6.5–10.5). Die goldene Linie (IMDb, Marker-Grösse 8) bleibt nahezu flach bei ~7.9. Die rote Linie (RT-Kritiker normalisiert) schwankt stärker: Höchstwert in den 1970ern (9.30), Tiefpunkt in den 2000ern (8.15), Erholung auf 8.88 in den 2010ern. Zwei Annotationen mit Pfeilen: „Peak: New-Hollywood-Ära" und „Tief: Franchise-Dominanz". Der Tooltip zeigt pro Jahrzehnt Dekade, Anzahl Filme, Ø IMDb und Ø RT-Kritiker.

Unten ein Hinweistext: „Jahrzehnte vor 1960 ausgeblendet: Die wenigen gematchten Altfilme (z.B. Chaplin, Metropolis) sind nicht repräsentativ für die jeweilige Epoche (n < 48)."

---

#### Tab 5: Popularität – Bekanntheit vs. Bewertungsunterschied

![[05_Popularitaet.png]]

Links ein Scatterplot (ggplotly): x-Achse log10(Anzahl IMDb-Votes, Bereich 4.5–6.0), y-Achse Differenz IMDb − RT-Kritiker (Bereich −2 bis +4). Punkte sind nach IMDb-Rating eingefärbt (Farbskala Blau 8.0 bis Rot 9.0). Gestrichelte weisse Nulllinie und weisse Regresslinie – je mehr Votes, desto kleiner die Differenz.

Rechts ein Boxplot nach vier Vote-Buckets (<100k, 100k–500k, 500k–1M, >1M) mit Farbverlauf (Hellblau bis Dunkelblau). Der >1M-Bucket zeigt die kompakteste Box nahe der Nulllinie. Unten eine DT-Tabelle: <100k (7.835, −1.308, 181 Filme), 100k–500k (7.874, −0.789, 302), 500k–1M (8.048, −0.852, 124), >1M (8.546, −0.176, 37).

---

#### Tab 6: Zuverlässigkeit – Wie belastbar sind die Kritiken?

![[06_Zuverlaessigkeit.png]]

Oben drei ValueBoxen: Median der Kritikanzahl (90, Gelb), 9 Filme mit < 20 Kritiken (geflaggt, Rot), 532 Certified-Fresh-Filme (Grün). In der nächsten Zeile zwei Scatterplots nebeneinander: Links „Kritikanzahl vs. Tomatometer-Rating" (x-Achse 0–600, y-Achse 40–100%) – Punkte nach Tomatometer-Status eingefärbt (Certified-Fresh, Fresh, Rotten), gestrichelte 20-Kritiken-Linie. Rechts „Kritikanzahl vs. absolute Bewertungsdifferenz" (x-Achse 0–600, y-Achse 0–5, Blaue Punkte) mit Trendlinie.

Darunter ein Boxplot „IMDb Rating nach Tomatometer-Status" (y-Achse 8.0–9.0): Certified-Fresh (Rot), Fresh (Gold), Rotten (Grau). Die Rotten-Box liegt am höchsten – typische Publikumslieblinge. Rechts eine DT-Tabelle der Low-Critic-Filme (Spalten: Film, Jahr, IMDb Rating, Tomatometer, Kritiken, Differenz).

---

#### Tab 7: Datenqualität – Transparente Qualitätssicherung

![[07_Datenqualitaet.png]]

Oben vier ValueBoxen: Fehlende Kernwerte (0), Dubletten (0), Match-Typen erkannt (2), Potenziell instabile RT-Werte (9). Links eine DT-Tabelle „Datenqualitäts-Kennzahlen" mit 11 Zeilen (z.B. Zeilen im Datensatz 644, fehlende Werte je 0, IMDb-Min/Max 7.6/9.3, RT-Min/Max 2.6/10, Filme < 20 Kritiken 9, Distinct Genres 13).

Rechts ein horizontales Balkendiagramm „Fehlende Werte je Kernvariable" – 7 Variablen, alle auf 0. Darunter links ein Balkendiagramm „Matching-Qualität": exact = 630, fuzzy = 14 (in goldener IMDb-Farbe). Rechts eine DT-Tabelle der fehlenden Werte – ebenfalls alles null.

---

#### Tab 8: Datentabelle – Der vollständige Datensatz

![[08_Datentabelle.png]]

Der letzte Tab bietet alle 644 Filme als interaktive DT-Tabelle mit 12 Spalten: Film, Jahr, Genre, IMDb, RT-Kritiker, RT-Publikum, Differenz, |Differenz|, Anz. Kritiken, Status, Votes, match_type (exact/fuzzy). Jede Spalte hat eine eigene Filter-Box und ist sortierbar. Oben links ein Dropdown für die Anzahl angezeigter Zeilen (10/15/25/50/100), oben rechts eine globale Suchfunktion. Beispiel: The Shawshank Redemption (1994, Drama, IMDb 9.3, RT-Kritiker 9.1, RT-Publikum 9.8, Differenz 0.2, 75 Kritiken, Certified-Fresh, 2.3 Mio. Votes, exact).

---

## 4. Ergebnisse

### 4.1 Korrelationsanalyse (Kernbefund)

| Vergleich | Pearson r | 95%-Konfidenzintervall | p-Wert | Interpretation |
|:----------|----------:|:----------------------:|-------:|:---------------|
| IMDb (Publikum) vs. RT-Kritiker | **0.228** | [0.154, 0.300] | < 0.001 | Schwache Korrelation |
| IMDb (Publikum) vs. RT-Publikum | **0.489** | [0.427, 0.545] | < 0.001 | Moderate Korrelation |
| RT-Kritiker vs. RT-Publikum | **0.371** | [0.302, 0.436] | < 0.001 | Schwache bis moderate Korrelation |

Alle drei Korrelationen sind statistisch hochsignifikant (p < 0.001). Die Konfidenzintervalle überlappen nicht zwischen IMDb-vs-RT-Kritiker und IMDb-vs-RT-Publikum, was den Unterschied bestätigt.

**Zentrales Ergebnis:** Die Publikumsmeinungen auf IMDb und Rotten Tomatoes stimmen deutlich stärker überein (r = 0.489) als die Bewertungen zwischen Publikum und Kritikern (r = 0.228). Kritiker und Publikum bewerten Filme offenbar nach unterschiedlichen Massstäben.

### 4.2 Systematische Abweichung

Die durchschnittliche Differenz (IMDb − Tomatometer normalisiert) beträgt **−0.912 Punkte**.

- **t-Test** (H₀: Ø Differenz = 0): t(643) = −22.22, **p < 0.001**
- **Effektstärke:** Cohen's d = −0.88 (grosser Effekt nach Cohen's Konvention: |d| ≥ 0.8)

RT-Kritiker bewerten die gleichen Filme im Schnitt fast einen ganzen Punkt höher als das IMDb-Publikum – ein Unterschied, der statistisch hochsignifikant und praktisch bedeutsam ist.

### 4.3 Grösste Abweichungen

**IMDb bewertet deutlich höher als RT-Kritiker:**

| Film | Jahr | IMDb | RT (norm.) | Differenz |
|:-----|-----:|-----:|-----------:|----------:|
| The Boondock Saints | 1999 | 7.8 | 2.8 | **+5.0** |
| Seven Pounds | 2008 | 7.6 | 2.6 | **+5.0** |
| The Butterfly Effect | 2004 | 7.6 | 3.3 | +4.3 |
| I Am Sam | 2001 | 7.7 | 3.5 | +4.2 |
| Man on Fire | 2004 | 7.7 | 3.8 | +3.9 |

**RT-Kritiker bewerten deutlich höher als IMDb:**

| Film | Jahr | IMDb | RT (norm.) | Differenz |
|:-----|-----:|-----:|-----------:|----------:|
| Love and Death | 1975 | 7.7 | 10.0 | **−2.3** |
| The Taking of Pelham 123 | 1974 | 7.7 | 10.0 | **−2.3** |
| Cape Fear | 1962 | 7.7 | 10.0 | **−2.3** |
| The Ladykillers | 1955 | 7.7 | 10.0 | **−2.3** |
| A Hard Day's Night | 1964 | 7.6 | 9.8 | −2.2 |

Die grössten Ausschläge nach oben (+5.0) sind grösser als nach unten (−2.3). Dies liegt am Selektionsbias: IMDb-Ratings starten bei 7.6, sodass der maximale negative Ausschlag begrenzt ist.

**Skalenasymmetrie:** Die IMDb-Ratings im Datensatz umfassen nur **1.7 Punkte** (7.6–9.3), der normalisierte Tomatometer dagegen **7.4 Punkte** (2.6–10.0). Kritiker differenzieren also rund **4× stärker** zwischen den gleichen Top-Filmen als das IMDb-Publikum.

### 4.4 Genre-Analyse

9 Genres haben mindestens 5 Filme im Datensatz:

| Genre | Ø IMDb | Ø RT-Kritiker | Ø Differenz | n |
|:------|-------:|--------------:|------------:|--:|
| Animation | 7.92 | 9.29 | **−1.37** | 46 |
| Comedy | 7.88 | 8.98 | **−1.11** | 106 |
| Drama | 7.95 | 8.91 | −0.97 | 165 |
| Horror | 7.92 | 8.79 | −0.87 | 10 |
| Crime | 8.02 | 8.86 | −0.83 | 65 |
| Adventure | 7.94 | 8.72 | −0.78 | 60 |
| Biography | 7.92 | 8.66 | −0.74 | 71 |
| Action | 7.93 | 8.61 | −0.65 | 106 |
| Mystery | 8.04 | 8.41 | −0.37 | 7 |

Die grössten Diskrepanzen zeigen sich bei **Animation** (−1.37) und **Comedy** (−1.11). Bei **Mystery** (−0.37) und **Action** (−0.65) sind sich Publikum und Kritiker am nächsten.

### 4.5 Zeittrend (Dekaden-Analyse)

| Dekade | Ø IMDb | Ø RT-Kritiker | Filme |
|:-------|-------:|--------------:|------:|
| 1960er | 7.93 | 9.23 | 48 |
| 1970er | 7.94 | **9.30** | 51 |
| 1980er | 7.96 | 8.89 | 60 |
| 1990er | 7.97 | 8.62 | 101 |
| 2000er | 7.90 | **8.15** | 133 |
| 2010er | 7.89 | 8.88 | 138 |

Die IMDb-Ratings bleiben über die Jahrzehnte stabil (~7.9). Die Kritikerbewertungen schwanken stärker: Der Höchstwert in den 1970ern fällt mit der **New-Hollywood-Ära** zusammen (Coppola, Scorsese, Spielberg, Kubrick). Der Rückgang in den 2000ern könnte die zunehmende Franchise-Dominanz widerspiegeln. Dekaden vor 1960 wurden ausgeblendet (n < 48, Survivorship-Effekt).

### 4.6 Popularitätsanalyse

| Vote-Bucket | Ø IMDb | Ø Differenz | Filme |
|:------------|-------:|------------:|------:|
| < 100k | 7.84 | **−1.31** | 181 |
| 100k–500k | 7.87 | −0.79 | 302 |
| 500k–1M | 8.05 | −0.85 | 124 |
| > 1M | 8.55 | −0.18 | 37 |

Hochpopuläre Filme (>1M Votes) haben die kleinste Bewertungslücke (−0.18) und das höchste Durchschnittsrating (8.55). Bei diesen Blockbustern stimmen Publikum und Kritiker fast überein. Weniger bekannte Filme (<100k Votes) zeigen die grösste Diskrepanz (−1.31).

### 4.7 Zuverlässigkeit

- **Median Kritikanzahl:** 90 Besprechungen pro Film
- **Certified-Fresh Filme:** 532 von 644 (82.6%)
- **Filme mit <20 Kritiken:** 9 Filme (geflaggt als potenziell unzuverlässig)

| Tomatometer-Status | Ø IMDb | Ø Differenz | Filme |
|:-------------------|-------:|------------:|------:|
| Certified-Fresh | 7.96 | **−1.12** | 532 |
| Fresh | 7.86 | −0.34 | 99 |
| Rotten | 7.66 | **+3.17** | 13 |

**Certified-Fresh-Paradox:** Kontraintuitiv zeigen Certified-Fresh-Filme eine grössere Differenz (−1.12) als „nur" Fresh-Filme (−0.34). Die Erklärung liegt in der Skalenasymmetrie (vgl. 4.3): Kritiker vergeben bei den besten Filmen ihre höchsten Scores, während das IMDb-Publikum auch diese Filme im engen Bereich um 7.96 bewertet. Die 13 „Rotten"-Filme (Ø IMDb 7.66, Differenz +3.17) sind typische Publikumslieblinge, die bei Kritikern durchfallen.

---

## 5. Diskussion

### 5.1 Interpretation der Ergebnisse

Die Analyse bestätigt, dass **Publikum und Kritiker Filme unterschiedlich bewerten**. Die schwache Korrelation (r = 0.228) zwischen IMDb und RT-Kritikern zeigt, dass professionelle Filmkritik anderen Massstäben folgt als die kollektive Publikumsmeinung.

Gleichzeitig ist die „Stimme des Publikums" **plattformübergreifend konsistent** (r = 0.489). Egal ob auf IMDb oder Rotten Tomatoes – Zuschauer bewerten ähnlich.

Besonders aufschlussreich ist die **Skalenasymmetrie**: Kritiker differenzieren 4× stärker zwischen Filmen als das Publikum (7.4 vs. 1.7 Punkte Spread). Dies führt zum Certified-Fresh-Paradox (vgl. 4.7) und erklärt, warum die Korrelation zwischen Publikum und Kritikern strukturell niedrig ausfallen muss.

### 5.2 Limitationen

1. **Selektionsbias:** Der IMDb-Datensatz enthält nur die Top 1'000 Filme (Ratings 7.6–9.3). Die Ergebnisse sind nicht auf durchschnittliche oder schlecht bewertete Filme übertragbar.
2. **Matching-Verlust:** Von 1'000 IMDb-Filmen konnten 644 mit RT-Einträgen gematcht werden (630 exakt + 14 per Fuzzy Matching). ~356 Filme bleiben ohne Match.
3. **Genre-Vereinfachung:** Es wird nur das erste Genre pro Film genutzt. Multi-Genre-Filme werden nur dem ersten zugeordnet.
4. **Zeitliche Verzerrung:** Ältere Filme sind per Definition „Klassiker" (Survivorship Bias).

### 5.3 Mögliche Erweiterungen

- Sentimentanalyse von Review-Texten
- Vergleich mit weiteren Plattformen (Metacritic, Letterboxd)
- Zeitreihenanalyse: Wie verändern sich Ratings eines Films über die Jahre?
- Regressionsanalyse: Welche Variablen erklären die Bewertungsdifferenz?

---

## 6. Fazit

Unsere Analyse von 644 Filmen zeigt drei zentrale Erkenntnisse:

1. **Publikum ist sich einig:** IMDb- und RT-Publikumsbewertungen korrelieren mit r = 0.489 (95% KI [0.427, 0.545]) – die „Stimme des Publikums" ist plattformübergreifend konsistent.

2. **Kritiker weichen ab:** Die Korrelation zwischen IMDb-Publikum und RT-Kritikern ist mit r = 0.228 schwach. Kritiker bewerten die gleichen Top-Filme im Schnitt 0.9 Punkte höher (t = −22.22, p < 0.001, Cohen's d = −0.88).

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
[3] NACH DATENTRANSFORMATION – 630 exakt + 14 fuzzy = 644 Filme
[4] QUALITÄTSPRÜFUNG – ✓ Alle Prüfungen bestanden
[5] ANALYSE-ERGEBNISSE – r(IMDb, RT-Kritiker): 0.228 [95% KI: 0.154–0.300]
✓ Pipeline vollständig abgeschlossen.
```

---

## 8. Quellen

### 8.1 Datensätze

- **IMDb Top 1000 Movies Dataset.** Kaggle. <https://www.kaggle.com/datasets/harshitshankhdhar/imdb-dataset-of-top-1000-movies-and-tv-shows>
- **Rotten Tomatoes Movies and Critic Reviews Dataset.** Kaggle. <https://www.kaggle.com/datasets/stefanoleone992/rotten-tomatoes-movies-and-critic-reviews-dataset>

### 8.2 Statistische Methoden

- **Cohen, J. (1988).** *Statistical Power Analysis for the Behavioral Sciences* (2. Aufl.). Lawrence Erlbaum Associates.
- **Jaro, M. A. (1989).** Advances in record-linkage methodology. *Journal of the American Statistical Association*, 84(406), 414–420.
- **Winkler, W. E. (1990).** String Comparator Metrics and Enhanced Decision Rules. *Proceedings of the Section on Survey Research Methods*, 354–359.

### 8.3 Software

- **R Core Team (2025).** *R: A Language and Environment for Statistical Computing.* <https://www.R-project.org/>
- **Wickham, H. et al. (2019).** Welcome to the tidyverse. *JOSS*, 4(43), 1686.
- **van der Loo, M. P. J. (2014).** The stringdist Package for Approximate String Matching. *The R Journal*, 6(1), 111–122.
- **Chang, W. et al.** *shiny: Web Application Framework for R.*
- **Sievert, C. (2020).** *Interactive Web-Based Data Visualization with R, plotly, and shiny.* Chapman & Hall/CRC.

---

## Anhang: Projektstruktur

| Datei | Zweck | Zeilen |
|:------|:------|-------:|
| `pipeline.R` | 5-Schritt-Daten-Pipeline (Fuzzy Matching + Inferenzstatistik) | ~360 |
| `app.R` | Shiny Dashboard (8 Tabs, UI + Server, Custom CSS) | ~1'370 |
| `install_packages.R` | Einmalige Package-Installation | ~55 |
| `versions.txt` | Package-Versionen für Reproduzierbarkeit | – |
| `sessionInfo.txt` | Auto-generierter Reproduzierbarkeits-Snapshot | – |
| `imdb_top_1000.csv` | IMDb-Rohdaten | 1'000 |
| `rotten_tomatoes_movies.csv` | RT-Rohdaten | 17'712 |
| `README.md` | Projekt-Dokumentation | – |
| `Projektbericht.md` | Dieser Bericht | – |
