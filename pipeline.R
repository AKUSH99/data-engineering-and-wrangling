# =============================================================
#  IMDb vs. Rotten Tomatoes – Der grosse Rating-Vergleich
#  Daten-Pipeline (R / tidyverse)
#  FHNW Datenprojekt
# =============================================================

library(readr)
library(dplyr)
library(tidyr)
library(stringr)
library(stringdist)

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
      Released_Year    = as.integer(suppressWarnings(as.numeric(Released_Year))),
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
# - Zwei-Stufen-Matching:
#   1. Exakter Join über (normalisierter Titel + Jahr)
#   2. Fuzzy Matching (Jaro-Winkler, Schwelle 0.12) für nicht-gematchte Filme
#      mit gleichem Erscheinungsjahr → fängt Tippfehler und Titelvariation ab
# - Neue Variablen: rating_diff, primary_genre, decade, low_critic_count

transform_data <- function(clean) {

  df_rt_t <- clean$rt %>%
    mutate(
      tomatometer_normalized = tomatometer_rating / 10,
      audience_normalized    = audience_rating    / 10
    )

  rt_cols <- df_rt_t %>%
    select(Title_clean, release_year, tomatometer_normalized,
           audience_normalized, tomatometer_rating,
           tomatometer_count, tomatometer_status)

  # --- Stufe 1: Exakter Join ---
  df_exact <- inner_join(
    clean$imdb, rt_cols,
    by = c("Title_clean", "Released_Year" = "release_year")
  )

  # --- Stufe 2: Fuzzy Matching für nicht-gematchte ---
  imdb_unmatched <- clean$imdb %>%
    filter(!Title_clean %in% df_exact$Title_clean)

  fuzzy_matches <- NULL
  if (nrow(imdb_unmatched) > 0) {
    fuzzy_rows <- list()
    for (i in seq_len(nrow(imdb_unmatched))) {
      row <- imdb_unmatched[i, ]
      candidates <- rt_cols %>% filter(release_year == row$Released_Year)
      if (nrow(candidates) == 0) next
      dists <- stringdist::stringdist(row$Title_clean, candidates$Title_clean,
                                       method = "jw")
      best_idx <- which.min(dists)
      if (dists[best_idx] < 0.12) {
        fuzzy_rows[[length(fuzzy_rows) + 1]] <- bind_cols(
          row %>% select(-Title_clean),
          candidates[best_idx, ] %>% select(-Title_clean, -release_year)
        )
      }
    }
    if (length(fuzzy_rows) > 0) {
      fuzzy_matches <- bind_rows(fuzzy_rows)
    }
  }

  # --- Zusammenführen ---
  if (!is.null(fuzzy_matches)) {
    df_merged <- bind_rows(df_exact, fuzzy_matches)
  } else {
    df_merged <- df_exact
  }
  n_fuzzy <- nrow(df_merged) - nrow(df_exact)

  df_merged <- df_merged %>%
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
  message(sprintf("    Gematchte Filme (exakt):       %d", nrow(df_exact)))
  message(sprintf("    Gematchte Filme (fuzzy):       %d", n_fuzzy))
  message(sprintf("    Gematchte Filme (gesamt):      %d", nrow(df_merged)))
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

  # Korrelationen mit Konfidenzintervallen
  ct_critics  <- cor.test(df$IMDB_Rating, df$tomatometer_normalized)
  ct_audience <- cor.test(df$IMDB_Rating, df$audience_normalized)
  ct_cross    <- cor.test(df$tomatometer_normalized, df$audience_normalized)

  corr_critics  <- ct_critics$estimate
  corr_audience <- ct_audience$estimate
  corr_cross    <- ct_cross$estimate

  # t-Test: Ist die mittlere Differenz (IMDb − RT) signifikant ≠ 0?
  ttest_diff <- t.test(df$rating_diff, mu = 0)

  # Effektstärke (Cohen's d)
  cohens_d <- mean(df$rating_diff) / sd(df$rating_diff)

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
  message(sprintf("    r(IMDb, RT-Kritiker):  %.3f  [95%% KI: %.3f – %.3f], p = %.2e",
                  corr_critics, ct_critics$conf.int[1], ct_critics$conf.int[2], ct_critics$p.value))
  message(sprintf("    r(IMDb, RT-Publikum):  %.3f  [95%% KI: %.3f – %.3f], p = %.2e  <- deutlich stärker!",
                  corr_audience, ct_audience$conf.int[1], ct_audience$conf.int[2], ct_audience$p.value))
  message(sprintf("    r(Kritiker, Publikum): %.3f  [95%% KI: %.3f – %.3f], p = %.2e",
                  corr_cross, ct_cross$conf.int[1], ct_cross$conf.int[2], ct_cross$p.value))
  message(sprintf("    Ø Differenz (IMDb-RT): %.3f  (t = %.2f, p = %.2e, Cohen's d = %.2f)",
                  mean(df$rating_diff), ttest_diff$statistic, ttest_diff$p.value, cohens_d))

  list(
    corr_critics  = corr_critics,
    corr_audience = corr_audience,
    corr_cross    = corr_cross,
    ci_critics    = ct_critics$conf.int,
    ci_audience   = ct_audience$conf.int,
    ci_cross      = ct_cross$conf.int,
    p_critics     = ct_critics$p.value,
    p_audience    = ct_audience$p.value,
    p_cross       = ct_cross$p.value,
    ttest_diff    = ttest_diff,
    cohens_d      = cohens_d,
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
