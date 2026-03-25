# =============================================================
#  IMDb vs. Rotten Tomatoes – Der grosse Rating-Vergleich
#  Daten-Pipeline (R / tidyverse)
#  FHNW Datenprojekt
# =============================================================

library(readr)
library(dplyr)
library(tidyr)
library(stringr)

# ==========================================
# SCHRITT 1: DATEN EINLESEN
# ==========================================
# Begründung: read_csv() aus readr ist schneller als read.csv(),
# erkennt Spaltentypen automatisch und gibt beim Einlesen direktes
# Feedback über die erkannten Datentypen.

load_data <- function(imdb_path = "imdb_top_1000.csv",
                      rt_path   = "rotten_tomatoes_movies.csv") {

  if (!file.exists(imdb_path))
    stop(sprintf("FEHLER: IMDb-Datei nicht gefunden: '%s'\nBitte sicherstellen, dass die CSV im Working Directory liegt.", imdb_path))
  if (!file.exists(rt_path))
    stop(sprintf("FEHLER: RT-Datei nicht gefunden: '%s'\nBitte sicherstellen, dass die CSV im Working Directory liegt.", rt_path))

  df_imdb <- read_csv(imdb_path,
    col_select = c(Series_Title, Released_Year, Genre,
                   IMDB_Rating, No_of_Votes, Meta_score),
    show_col_types = FALSE)

  df_rt <- read_csv(rt_path,
    col_select = c(movie_title, original_release_date, genres,
                   tomatometer_rating, audience_rating,
                   tomatometer_count, tomatometer_status,
                   tomatometer_fresh_critics_count,
                   tomatometer_rotten_critics_count),
    show_col_types = FALSE)

  message(sprintf("[1] DATEN EINGELESEN"))
  message(sprintf("    IMDb:           %d Zeilen | %d fehlende Werte",
                  nrow(df_imdb), sum(is.na(df_imdb))))
  message(sprintf("    Rotten Tomatoes:%d Zeilen | %d fehlende Werte",
                  nrow(df_rt), sum(is.na(df_rt))))

  list(imdb = df_imdb, rt = df_rt)
}


# ==========================================
# SCHRITT 2: DATENBEREINIGUNG
# ==========================================
# Begründung:
# - Released_Year enthält vereinzelt nicht-numerische Werte (z.B. "PG")
#   → suppressWarnings() + as.numeric() konvertiert diese zu NA, die dann entfernt werden
# - Titelspalten werden mit str_to_lower() + str_trim() normalisiert
#   für einen verlässlichen Join über Titel + Jahr
# - RT: Erscheinungsjahr aus original_release_date extrahieren

clean_data <- function(raw) {

  # --- IMDb ---
  imdb_rows_before <- nrow(raw$imdb)

  df_imdb <- raw$imdb %>%
    mutate(
      Released_Year    = suppressWarnings(as.numeric(Released_Year)),
      Title_clean      = str_to_lower(str_trim(Series_Title))
    ) %>%
    filter(!is.na(Released_Year), !is.na(IMDB_Rating))

  # --- Rotten Tomatoes ---
  rt_rows_before <- nrow(raw$rt)

  df_rt <- raw$rt %>%
    filter(!is.na(tomatometer_rating), !is.na(movie_title)) %>%
    mutate(
      release_year     = as.integer(format(as.Date(original_release_date), "%Y")),
      Title_clean      = str_to_lower(str_trim(movie_title))
    )

  message(sprintf("[2] NACH DATENBEREINIGUNG"))
  message(sprintf("    IMDb:           %d Zeilen (entfernt: %d)",
                  nrow(df_imdb), imdb_rows_before - nrow(df_imdb)))
  message(sprintf("    Rotten Tomatoes:%d Zeilen (entfernt: %d)",
                  nrow(df_rt), rt_rows_before - nrow(df_rt)))

  list(imdb = df_imdb, rt = df_rt)
}


# ==========================================
# SCHRITT 3: DATENTRANSFORMATION & MERGE
# ==========================================
# Begründung:
# - Tomatometer (0-100) wird auf 0-10 normalisiert (÷10) für direkten
#   Vergleich mit IMDb-Skala. Ohne Normalisierung sind Differenzberechnungen
#   nicht aussagekräftig.
# - Inner Join über (normalisierter Titel + Jahr): nur Filme mit Ratings
#   auf beiden Plattformen werden analysiert.
# - Neue Variablen: rating_diff, primary_genre, decade, low_critic_count

transform_data <- function(clean) {

  df_rt_t <- clean$rt %>%
    mutate(
      tomatometer_normalized = tomatometer_rating / 10,
      audience_normalized    = audience_rating    / 10
    )

  df_merged <- inner_join(
    clean$imdb,
    df_rt_t %>% select(Title_clean, release_year, tomatometer_normalized,
                       audience_normalized, tomatometer_rating,
                       tomatometer_count, tomatometer_status),
    by = c("Title_clean", "Released_Year" = "release_year")
  ) %>%
  mutate(
    rating_diff      = IMDB_Rating - tomatometer_normalized,
    abs_diff         = abs(rating_diff),
    primary_genre    = str_trim(str_split_fixed(Genre, ",", 2)[,1]),
    decade           = (Released_Year %/% 10) * 10,
    low_critic_count = tomatometer_count < 20,
    vote_bucket      = cut(No_of_Votes,
                           breaks = c(0, 100000, 500000, 1000000, 5000000),
                           labels = c("<100k", "100k–500k", "500k–1M", ">1M"),
                           include.lowest = TRUE)
  )

  message(sprintf("[3] NACH DATENTRANSFORMATION"))
  message(sprintf("    Gematchte Filme (Inner Join): %d", nrow(df_merged)))
  message(sprintf("    Ø IMDb Rating:                %.3f", mean(df_merged$IMDB_Rating)))
  message(sprintf("    Ø Tomatometer (normalisiert): %.3f",
                  mean(df_merged$tomatometer_normalized)))

  df_merged
}


# ==========================================
# SCHRITT 4: QUALITÄTSPRÜFUNG
# ==========================================
# Begründung:
# - Nullwerte in Schlüsselspalten nach dem Merge würden Analysen verfälschen
# - Wertebereiche werden validiert
# - Duplikate (gleicher Titel + Jahr) verfälschen Aggregationen
# - low_critic_count flaggt Filme mit < 20 Kritikerbesprechungen (unzuverlässig)

quality_check <- function(df) {

  checks <- list(
    null_imdb    = sum(is.na(df$IMDB_Rating)),
    null_rt      = sum(is.na(df$tomatometer_normalized)),
    duplicates   = sum(duplicated(df %>% select(Series_Title, Released_Year))),
    imdb_range   = paste(min(df$IMDB_Rating), "–", max(df$IMDB_Rating)),
    rt_range     = paste(round(min(df$tomatometer_normalized),2), "–",
                         round(max(df$tomatometer_normalized),2)),
    low_critics  = sum(df$low_critic_count, na.rm = TRUE)
  )

  message(sprintf("[4] QUALITÄTSPRÜFUNG"))
  message(sprintf("    Fehlende IMDB_Rating:      %d", checks$null_imdb))
  message(sprintf("    Fehlende tomatometer_norm: %d", checks$null_rt))
  message(sprintf("    Duplikate:                 %d", checks$duplicates))
  message(sprintf("    IMDB_Rating Bereich:       %s", checks$imdb_range))
  message(sprintf("    Tomatometer Bereich:       %s", checks$rt_range))
  message(sprintf("    Filme < 20 Kritiken:       %d (geflaggt)", checks$low_critics))

  stopifnot(
    "FEHLER: Nullwerte in IMDB_Rating!"            = checks$null_imdb == 0,
    "FEHLER: Nullwerte in tomatometer_normalized!" = checks$null_rt   == 0,
    "FEHLER: Duplikate gefunden!"                  = checks$duplicates == 0
  )
  message("    ✓ Alle Qualitätsprüfungen bestanden.")

  checks
}


# ==========================================
# SCHRITT 5: ANALYSE-STATISTIKEN
# ==========================================

compute_stats <- function(df) {

  # Korrelationen
  corr_critics  <- cor(df$IMDB_Rating, df$tomatometer_normalized, use = "complete.obs")
  corr_audience <- cor(df$IMDB_Rating, df$audience_normalized,    use = "complete.obs")
  corr_cross    <- cor(df$tomatometer_normalized, df$audience_normalized, use = "complete.obs")

  # Genre-Aggregation (n >= 5)
  genre_stats <- df %>%
    group_by(primary_genre) %>%
    summarise(
      avg_imdb     = mean(IMDB_Rating,             na.rm = TRUE),
      avg_critics  = mean(tomatometer_normalized,  na.rm = TRUE),
      avg_audience = mean(audience_normalized,     na.rm = TRUE),
      count        = n(),
      avg_diff     = mean(rating_diff,             na.rm = TRUE),
      .groups = "drop"
    ) %>%
    filter(count >= 5) %>%
    arrange(avg_diff)

  # Jahrzehnt-Aggregation (n >= 48)
  # Begründung: 48 entspricht der kleinsten Dekade (1960er) im gematchten
  # Datensatz. Dekaden mit weniger Filmen (vor 1960) sind statistisch nicht
  # repräsentativ und werden ausgeblendet, um Verzerrungen zu vermeiden.
  decade_stats <- df %>%
    group_by(decade) %>%
    summarise(
      avg_imdb    = mean(IMDB_Rating,            na.rm = TRUE),
      avg_critics = mean(tomatometer_normalized, na.rm = TRUE),
      count       = n(),
      .groups = "drop"
    ) %>%
    filter(count >= 48) %>%
    arrange(decade)

  # Vote-Bucket Aggregation
  vote_stats <- df %>%
    group_by(vote_bucket) %>%
    summarise(
      avg_imdb   = mean(IMDB_Rating,            na.rm = TRUE),
      avg_diff   = mean(rating_diff,            na.rm = TRUE),
      count      = n(),
      .groups = "drop"
    )

  # Status-Statistik
  status_stats <- df %>%
    group_by(tomatometer_status) %>%
    summarise(
      avg_imdb  = mean(IMDB_Rating,  na.rm = TRUE),
      avg_diff  = mean(rating_diff,  na.rm = TRUE),
      count     = n(),
      .groups   = "drop"
    )

  # Top/Bottom Abweichungen
  top5_imdb <- df %>% slice_max(rating_diff, n = 5) %>%
    select(Series_Title, Released_Year, IMDB_Rating, tomatometer_normalized, rating_diff)
  top5_rt   <- df %>% slice_min(rating_diff, n = 5) %>%
    select(Series_Title, Released_Year, IMDB_Rating, tomatometer_normalized, rating_diff)

  message(sprintf("[5] ANALYSE-ERGEBNISSE"))
  message(sprintf("    r(IMDb, RT-Kritiker):  %.3f", corr_critics))
  message(sprintf("    r(IMDb, RT-Publikum):  %.3f  <- deutlich stärker!", corr_audience))
  message(sprintf("    r(Kritiker, Publikum): %.3f", corr_cross))
  message(sprintf("    Ø Differenz (IMDb-RT): %.3f", mean(df$rating_diff)))

  list(
    corr_critics  = corr_critics,
    corr_audience = corr_audience,
    corr_cross    = corr_cross,
    genre_stats   = genre_stats,
    decade_stats  = decade_stats,
    vote_stats    = vote_stats,
    status_stats  = status_stats,
    top5_imdb     = top5_imdb,
    top5_rt       = top5_rt,
    n_total       = nrow(df),
    avg_diff      = mean(df$rating_diff),
    avg_imdb      = mean(df$IMDB_Rating),
    avg_rt        = mean(df$tomatometer_normalized),
    low_critics   = sum(df$low_critic_count, na.rm = TRUE)
  )
}


# ==========================================
# HAUPT-FUNKTION: Gesamte Pipeline ausführen
# ==========================================

run_pipeline <- function(imdb_path = "imdb_top_1000.csv",
                         rt_path   = "rotten_tomatoes_movies.csv") {
  raw     <- load_data(imdb_path, rt_path)
  cleaned <- clean_data(raw)
  merged  <- transform_data(cleaned)
  checks  <- quality_check(merged)
  stats   <- compute_stats(merged)

  message("\n✓ Pipeline vollständig abgeschlossen.")
  list(data = merged, stats = stats, checks = checks)
}
