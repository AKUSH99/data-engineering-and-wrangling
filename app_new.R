# =============================================================
#  IMDb vs. Rotten Tomatoes – Shiny Dashboard (Projektreife Version)
#  FHNW Datenprojekt
#  Starten: shiny::runApp("app.R") oder Run App in RStudio
# =============================================================

library(shiny)
library(shinydashboard)
library(ggplot2)
library(dplyr)
library(plotly)
library(DT)
library(scales)
library(RColorBrewer)

source("pipeline.R")

# ==========================================
# ROBUSTES LADEN DER PIPELINE
# ==========================================
result <- tryCatch(
  run_pipeline(),
  error = function(e) {
    stop("Pipeline konnte nicht ausgef\u00fchrt werden: ", e$message)
  }
)

df    <- result$data
stats <- result$stats

# ==========================================
# KONSTANTEN / DESIGN
# ==========================================
COLORS <- list(
  imdb     = "#F5C518",
  critics  = "#FA320A",
  audience = "#4A90D9",
  bg       = "#16213e",
  bg_outer = "#1a1a2e",
  sidebar  = "#0f0f23",
  text     = "#ccc",
  text_light = "#ddd",
  grid     = "#444",
  muted    = "#888888",
  success  = "#28a745"
)

# ==========================================
# HELFERFUNKTIONEN
# ==========================================
corr_label <- function(r) {
  if (is.na(r)) return("keine Korrelation berechenbar")
  if (abs(r) < 0.2) return("sehr schwache Korrelation")
  if (abs(r) < 0.4) return("schwache Korrelation")
  if (abs(r) < 0.6) return("mittlere Korrelation")
  if (abs(r) < 0.8) return("starke Korrelation")
  "sehr starke Korrelation"
}

theme_dashboard <- function() {
  theme_dark() +
    theme(
      plot.background   = element_rect(fill = COLORS$bg, color = NA),
      panel.background  = element_rect(fill = COLORS$bg, color = NA),
      panel.grid.major  = element_line(color = "#2a355c", linewidth = 0.3),
      panel.grid.minor  = element_line(color = "#223055", linewidth = 0.2),
      text              = element_text(color = COLORS$text),
      axis.text         = element_text(color = COLORS$text),
      axis.title        = element_text(color = COLORS$text_light),
      plot.title        = element_text(color = COLORS$text_light, face = "bold"),
      legend.background = element_rect(fill = COLORS$bg, color = NA),
      legend.key        = element_rect(fill = COLORS$bg, color = NA),
      legend.title      = element_text(color = COLORS$text_light),
      legend.text       = element_text(color = COLORS$text),
      strip.background  = element_rect(fill = COLORS$bg_outer, color = NA),
      strip.text        = element_text(color = COLORS$text_light)
    )
}

plotly_dark_layout <- function(p, ...) {
  p %>%
    layout(
      paper_bgcolor = COLORS$bg,
      plot_bgcolor  = COLORS$bg,
      font = list(color = COLORS$text),
      ...
    ) %>%
    config(displaylogo = FALSE, responsive = TRUE)
}

# ==========================================
# ABGELEITETE / QA-DATEN
# ==========================================
df <- df %>%
  mutate(
    abs_rating_diff = abs(rating_diff),
    votes_log10     = if_else(No_of_Votes > 0, log10(No_of_Votes), NA_real_)
  )

genre_choices <- sort(unique(stats$genre_stats$primary_genre))

# Match-Qualitaet
match_quality_df <- NULL
if ("match_type" %in% names(df)) {
  match_quality_df <- df %>%
    count(match_type, sort = TRUE, name = "Anzahl") %>%
    rename(`Match-Typ` = match_type)
}

# Fehlende Werte je Kernvariable
qa_missing_df <- data.frame(
  Variable = c(
    "IMDB_Rating", "tomatometer_normalized", "audience_normalized",
    "tomatometer_count", "No_of_Votes", "primary_genre", "Released_Year"
  ),
  Fehlende_Werte = c(
    sum(is.na(df$IMDB_Rating)),
    sum(is.na(df$tomatometer_normalized)),
    sum(is.na(df$audience_normalized)),
    sum(is.na(df$tomatometer_count)),
    sum(is.na(df$No_of_Votes)),
    sum(is.na(df$primary_genre)),
    sum(is.na(df$Released_Year))
  ),
  stringsAsFactors = FALSE
)

# ==========================================
# UI
# ==========================================
ui <- dashboardPage(
  skin = "black",

  dashboardHeader(
    title = "IMDb vs. Rotten Tomatoes"
  ),

  dashboardSidebar(
    sidebarMenu(
      menuItem("\u00dcbersicht",          tabName = "overview",    icon = icon("chart-bar")),
      menuItem("Drei-Wege-Vergleich",  tabName = "threeway",    icon = icon("layer-group")),
      menuItem("Genre-Analyse",        tabName = "genre",       icon = icon("film")),
      menuItem("Zeittrend",            tabName = "decade",      icon = icon("clock")),
      menuItem("Popularit\u00e4t",          tabName = "popularity",  icon = icon("star")),
      menuItem("Zuverl\u00e4ssigkeit",      tabName = "reliability", icon = icon("check-circle")),
      menuItem("Datenqualit\u00e4t",        tabName = "quality",     icon = icon("shield-alt")),
      menuItem("Datentabelle",         tabName = "table",       icon = icon("table"))
    )
  ),

  dashboardBody(
    tags$head(tags$style(HTML("
      /* === GRUNDLAYOUT === */
      .content-wrapper { background-color: #1a1a2e; }
      .main-sidebar, .left-side { background-color: #0f0f23 !important; }
      .sidebar-menu > li > a { color: #ccc !important; }
      .sidebar-menu > li.active > a { color: #F5C518 !important; background-color: #16213e !important; }
      .sidebar-menu > li > a:hover { background-color: #16213e !important; color: #fff !important; }
      .skin-black .main-header .navbar { background-color: #0f0f23; }
      .skin-black .main-header .logo { background-color: #0f0f23; color: #F5C518 !important; }

      /* === BOXEN === */
      .box { background-color: #16213e; border-top: 3px solid #F5C518; color: #eee; }
      .box .box-header { color: #F5C518; font-weight: bold; }
      .box-body { color: #ddd; }
      .info-box { min-height: 80px; }
      .info-box-icon { height: 80px; line-height: 80px; }
      .info-box-content { padding-top: 10px; }
      .small-box { border-radius: 8px; }
      h4 { color: #F5C518; }

      /* === TABS === */
      .nav-tabs { border-bottom-color: #444; }
      .nav-tabs > li > a { color: #aaa; background-color: #16213e; border-color: #333; }
      .nav-tabs > li > a:hover { color: #fff; background-color: #1a1a2e; border-color: #555; }
      .nav-tabs > li.active > a,
      .nav-tabs > li.active > a:hover,
      .nav-tabs > li.active > a:focus {
        color: #F5C518 !important;
        background-color: #1a1a2e !important;
        border-color: #444;
        border-bottom-color: #1a1a2e;
      }
      .tab-content { background-color: transparent; }
      .nav-tabs-custom { background-color: transparent; }
      .nav-tabs-custom > .nav-tabs > li.active > a { color: #F5C518; }

      /* === TABELLEN === */
      .table { color: #ddd; background-color: #16213e; }
      .table-striped > tbody > tr:nth-of-type(odd) { background-color: #1a2240; }
      .table-striped > tbody > tr:nth-of-type(even) { background-color: #16213e; }
      .table-bordered { border-color: #333; }
      .table-bordered > thead > tr > th,
      .table-bordered > tbody > tr > td { border-color: #333; }
      .table > thead > tr > th {
        color: #F5C518;
        background-color: #0f0f23;
        border-bottom-color: #444;
      }

      /* === DT === */
      .dataTables_wrapper { color: #ccc; }
      .dataTables_wrapper .dataTables_length,
      .dataTables_wrapper .dataTables_filter,
      .dataTables_wrapper .dataTables_info,
      .dataTables_wrapper .dataTables_paginate { color: #ccc !important; }
      .dataTables_wrapper .dataTables_filter input,
      .dataTables_wrapper .dataTables_length select {
        color: #ddd;
        background-color: #1a1a2e;
        border: 1px solid #444;
      }
      table.dataTable thead { color: #F5C518; }
      table.dataTable thead th { background-color: #0f0f23 !important; }
      table.dataTable tbody td { color: #ddd; }
      table.dataTable tbody tr { background-color: #16213e !important; }
      table.dataTable tbody tr:hover { background-color: #1e2d50 !important; }
      .dataTables_wrapper .dataTables_paginate .paginate_button {
        color: #ccc !important;
        background-color: #16213e !important;
        border-color: #444 !important;
      }
      .dataTables_wrapper .dataTables_paginate .paginate_button.current {
        color: #F5C518 !important;
        background: #1a1a2e !important;
      }
      .dataTables_wrapper thead input,
      .dataTables_wrapper thead select {
        color: #ddd !important;
        background-color: #1a1a2e !important;
        border: 1px solid #444 !important;
      }

      /* === FORM === */
      .form-control {
        color: #ddd;
        background-color: #1a1a2e;
        border: 1px solid #444;
      }
      .selectize-input {
        color: #ddd !important;
        background-color: #1a1a2e !important;
        border-color: #444 !important;
      }
      .selectize-input.focus { border-color: #F5C518 !important; }
      .selectize-dropdown {
        color: #ddd;
        background-color: #16213e;
        border-color: #444;
      }
      .selectize-dropdown .active {
        background-color: #F5C518 !important;
        color: #000 !important;
      }
      .selectize-dropdown-content .option { color: #ddd; }
      .selectize-input .item { color: #ddd !important; }
      .selectize-input .remove { color: #FA320A !important; font-weight: bold; }
      .control-label { color: #ccc !important; }

      /* === HEADER === */
      .skin-black .main-header .navbar .sidebar-toggle { color: #ccc !important; }
      .skin-black .main-header .navbar .sidebar-toggle:hover {
        color: #F5C518 !important;
        background-color: #16213e !important;
      }
      .skin-black .main-header .navbar .nav > li > a { color: #ccc !important; }
      .skin-black .main-header .navbar .nav > li > a:hover { color: #fff !important; }

      /* === BOX TITEL === */
      .box-title { color: #F5C518 !important; }

      /* === PLOTLY === */
      .modebar-btn { fill: #aaa !important; }
      .modebar-btn:hover { fill: #F5C518 !important; }
      .modebar-group { background-color: transparent !important; }
    "))),

    tabItems(

      # ==========================================
      # TAB 1: \u00dcBERSICHT
      # ==========================================
      tabItem(
        tabName = "overview",
        fluidRow(
          valueBoxOutput("box_total", width = 3),
          valueBoxOutput("box_corr", width = 3),
          valueBoxOutput("box_avg_diff", width = 3),
          valueBoxOutput("box_bias", width = 3)
        ),
        fluidRow(
          box(
            title = "Bewertungsverteilung: IMDb vs. Tomatometer",
            width = 8, solidHeader = TRUE,
            plotlyOutput("plot_distribution", height = "350px")
          ),
          box(
            title = "Selektionsbias Hinweis",
            width = 4, solidHeader = TRUE,
            tags$div(
              style = "color: #ccc; font-size: 13px; line-height: 1.7;",
              tags$p(
                icon("exclamation-triangle", style = "color:#FA320A"),
                " Der IMDb-Datensatz enth\u00e4lt nur die ", tags$b("Top 1000"), " Filme."
              ),
              tags$hr(style = "border-color:#444"),
              tags$p(
                "IMDb-Ratings: ",
                tags$b(paste0(round(min(df$IMDB_Rating, na.rm = TRUE), 1),
                              " \u2013 ",
                              round(max(df$IMDB_Rating, na.rm = TRUE), 1))),
                " (nicht 1\u201310)"
              ),
              tags$p("RT-Scores hoch, weil Top-1000-Filme auch von Kritikern \u00fcberdurchschnittlich bewertet werden."),
              tags$p(
                tags$b(paste0(round(mean(df$tomatometer_normalized >= 9, na.rm = TRUE) * 100), "%")),
                " der Filme haben Tomatometer \u2265 90%"
              ),
              tags$hr(style = "border-color:#444"),
              tags$p(
                style = "color:#aaa; font-size:12px;",
                "Die Ergebnisse beschreiben das Bewertungsverhalten f\u00fcr \u00fcberdurchschnittlich gute Publikumsfilme, nicht den Gesamtmarkt."
              )
            )
          )
        ),
        fluidRow(
          box(
            title = "Scatterplot IMDb vs. Tomatometer",
            width = 6, solidHeader = TRUE,
            plotlyOutput("plot_scatter", height = "350px")
          ),
          box(
            title = "Top 5: Gr\u00f6sste Abweichungen",
            width = 6, solidHeader = TRUE,
            tabsetPanel(
              tabPanel("IMDb >> RT", DTOutput("table_top_imdb")),
              tabPanel("RT >> IMDb", DTOutput("table_top_rt"))
            )
          )
        )
      ),

      # ==========================================
      # TAB 2: DREI-WEGE-VERGLEICH
      # ==========================================
      tabItem(
        tabName = "threeway",
        fluidRow(
          infoBoxOutput("corr_critics_box", width = 4),
          infoBoxOutput("corr_audience_box", width = 4),
          infoBoxOutput("corr_cross_box", width = 4)
        ),
        fluidRow(
          box(
            title = "IMDb vs. RT-Kritiker vs. RT-Publikum",
            width = 12, solidHeader = TRUE,
            plotlyOutput("plot_threeway", height = "400px")
          )
        ),
        fluidRow(
          box(
            title = "\u00d8 Differenzen im Vergleich",
            width = 6, solidHeader = TRUE,
            plotlyOutput("plot_diff_bars", height = "300px")
          ),
          box(
            title = "Interpretation",
            width = 6, solidHeader = TRUE,
            uiOutput("interpretation_text")
          )
        )
      ),

      # ==========================================
      # TAB 3: GENRE-ANALYSE
      # ==========================================
      tabItem(
        tabName = "genre",
        fluidRow(
          box(
            width = 12, solidHeader = TRUE, title = "Filter",
            selectizeInput(
              "genre_filter",
              "Genre ausw\u00e4hlen:",
              choices = genre_choices,
              selected = genre_choices,
              multiple = TRUE,
              options = list(placeholder = "Ein oder mehrere Genres ausw\u00e4hlen")
            )
          )
        ),
        fluidRow(
          box(
            title = "Bewertung nach Genre \u2013 Drei Plattformen",
            width = 12, solidHeader = TRUE,
            plotlyOutput("plot_genre_grouped", height = "420px")
          )
        ),
        fluidRow(
          box(
            title = "Bewertungsdifferenz nach Genre (IMDb \u2212 RT-Kritiker)",
            width = 12, solidHeader = TRUE,
            plotlyOutput("plot_genre_diff", height = "350px")
          )
        )
      ),

      # ==========================================
      # TAB 4: ZEITTREND
      # ==========================================
      tabItem(
        tabName = "decade",
        fluidRow(
          box(
            title = "Bewertungstrend nach Jahrzehnt (ab 1960er, n \u2265 48)",
            width = 12, solidHeader = TRUE,
            plotlyOutput("plot_decade", height = "420px")
          ),
          box(
            width = 12, solidHeader = FALSE,
            tags$div(
              style = "color: #aaa; font-size: 12px;",
              icon("exclamation-triangle", style = "color:#FA320A"),
              " Jahrzehnte vor 1960 ausgeblendet: Die wenigen gematchten Altfilme (z.B. Chaplin, Metropolis) sind nicht repr\u00e4sentativ f\u00fcr die jeweilige Epoche (n < 48)."
            )
          )
        )
      ),

      # ==========================================
      # TAB 5: POPULARIT\u00c4T
      # ==========================================
      tabItem(
        tabName = "popularity",
        fluidRow(
          box(
            title = "log10(IMDb Votes) vs. Bewertungsdifferenz",
            width = 7, solidHeader = TRUE,
            plotlyOutput("plot_votes_scatter", height = "380px")
          ),
          box(
            title = "Bewertungsl\u00fccke nach Popularit\u00e4ts-Bucket",
            width = 5, solidHeader = TRUE,
            plotlyOutput("plot_votes_box", height = "380px")
          )
        ),
        fluidRow(
          box(
            title = "Popularit\u00e4ts-Statistik",
            width = 12, solidHeader = TRUE,
            DTOutput("table_votes")
          )
        )
      ),

      # ==========================================
      # TAB 6: ZUVERL\u00c4SSIGKEIT
      # ==========================================
      tabItem(
        tabName = "reliability",
        fluidRow(
          valueBoxOutput("box_median_critics", width = 4),
          valueBoxOutput("box_low_critics", width = 4),
          valueBoxOutput("box_certified", width = 4)
        ),
        fluidRow(
          box(
            title = "Kritikanzahl vs. Tomatometer-Rating",
            width = 6, solidHeader = TRUE,
            plotlyOutput("plot_reliability", height = "380px")
          ),
          box(
            title = "Kritikanzahl vs. absolute Bewertungsdifferenz",
            width = 6, solidHeader = TRUE,
            plotlyOutput("plot_reliability_diff", height = "380px")
          )
        ),
        fluidRow(
          box(
            title = "IMDb Rating nach Tomatometer-Status",
            width = 5, solidHeader = TRUE,
            plotlyOutput("plot_status_box", height = "360px")
          ),
          box(
            title = "Filme mit < 20 Kritikerbesprechungen (geflaggt)",
            width = 7, solidHeader = TRUE,
            DTOutput("table_low_critics")
          )
        )
      ),

      # ==========================================
      # TAB 7: DATENQUALIT\u00c4T
      # ==========================================
      tabItem(
        tabName = "quality",
        fluidRow(
          valueBoxOutput("box_missing_total", width = 3),
          valueBoxOutput("box_duplicates", width = 3),
          valueBoxOutput("box_match_types", width = 3),
          valueBoxOutput("box_unreliable", width = 3)
        ),
        fluidRow(
          box(
            title = "Datenqualit\u00e4ts-Kennzahlen",
            width = 6, solidHeader = TRUE,
            DTOutput("table_qa_metrics")
          ),
          box(
            title = "Fehlende Werte je Kernvariable",
            width = 6, solidHeader = TRUE,
            plotlyOutput("plot_missing", height = "320px")
          )
        ),
        fluidRow(
          box(
            title = "Matching-Qualit\u00e4t",
            width = 6, solidHeader = TRUE,
            plotlyOutput("plot_match_quality", height = "320px")
          ),
          box(
            title = "Fehlende Werte \u2013 Tabelle",
            width = 6, solidHeader = TRUE,
            DTOutput("table_missing")
          )
        )
      ),

      # ==========================================
      # TAB 8: DATENTABELLE
      # ==========================================
      tabItem(
        tabName = "table",
        fluidRow(
          box(
            title = paste0("Vollst\u00e4ndiger gemergter Datensatz (", nrow(df), " Filme)"),
            width = 12, solidHeader = TRUE,
            DTOutput("full_table")
          )
        )
      )
    )
  )
)

# ==========================================
# SERVER
# ==========================================
server <- function(input, output, session) {

  # ------------------------------------------
  # INITIALISIERUNG
  # ------------------------------------------
  observeEvent(TRUE, {
    updateSelectizeInput(
      session,
      "genre_filter",
      choices = genre_choices,
      selected = genre_choices,
      server = TRUE
    )
  }, once = TRUE)

  # ------------------------------------------
  # REAKTIVE DATEN
  # ------------------------------------------
  genre_data <- reactive({
    gs  <- stats$genre_stats
    sel <- input$genre_filter

    if (is.null(gs) || nrow(gs) == 0) return(data.frame())
    if (is.null(sel) || length(sel) == 0) return(gs)

    gs %>% filter(primary_genre %in% sel)
  })

  # ------------------------------------------
  # VALUE BOXES
  # ------------------------------------------
  output$box_total <- renderValueBox({
    valueBox(stats$n_total, "Analysierte Filme",
             icon = icon("film"), color = "yellow")
  })

  output$box_corr <- renderValueBox({
    valueBox(round(stats$corr_critics, 3), "Pearson r (IMDb vs. RT-Kritiker)",
             icon = icon("chart-line"), color = "red")
  })

  output$box_avg_diff <- renderValueBox({
    valueBox(round(stats$avg_diff, 3), "\u00d8 Differenz (IMDb \u2212 RT-Kritiker)",
             icon = icon("arrows-alt-v"), color = "orange")
  })

  output$box_bias <- renderValueBox({
    valueBox("Top 1000", "Selektionsbias IMDb",
             icon = icon("exclamation-triangle"), color = "red")
  })

  # ------------------------------------------
  # INFO BOXES DREI-WEGE (dynamische Korrelationslabels)
  # ------------------------------------------
  output$corr_critics_box <- renderInfoBox({
    infoBox("IMDb vs. RT-Kritiker", round(stats$corr_critics, 3),
            icon = icon("user-tie"), color = "red",
            subtitle = corr_label(stats$corr_critics))
  })

  output$corr_audience_box <- renderInfoBox({
    infoBox("IMDb vs. RT-Publikum", round(stats$corr_audience, 3),
            icon = icon("users"), color = "blue",
            subtitle = corr_label(stats$corr_audience))
  })

  output$corr_cross_box <- renderInfoBox({
    infoBox("RT-Kritiker vs. RT-Publikum", round(stats$corr_cross, 3),
            icon = icon("exchange-alt"), color = "yellow",
            subtitle = corr_label(stats$corr_cross))
  })

  # ------------------------------------------
  # RELIABILITY BOXES
  # ------------------------------------------
  output$box_median_critics <- renderValueBox({
    valueBox(round(median(df$tomatometer_count, na.rm = TRUE), 0),
             "Median Kritikanzahl",
             icon = icon("newspaper"), color = "yellow")
  })

  output$box_low_critics <- renderValueBox({
    n_low <- if ("low_critic_count" %in% names(df)) sum(df$low_critic_count, na.rm = TRUE) else NA
    valueBox(n_low, "Filme < 20 Kritiken (geflaggt)",
             icon = icon("flag"), color = "red")
  })

  output$box_certified <- renderValueBox({
    n_cert <- sum(df$tomatometer_status == "Certified-Fresh", na.rm = TRUE)
    valueBox(n_cert, "Certified-Fresh Filme",
             icon = icon("certificate"), color = "green")
  })

  # ------------------------------------------
  # DATENQUALIT\u00c4TS-BOXEN
  # ------------------------------------------
  output$box_missing_total <- renderValueBox({
    total_missing <- sum(
      is.na(df$IMDB_Rating),
      is.na(df$tomatometer_normalized),
      is.na(df$audience_normalized),
      is.na(df$tomatometer_count),
      is.na(df$No_of_Votes)
    )
    valueBox(total_missing, "Fehlende Kernwerte",
             icon = icon("database"), color = "orange")
  })

  output$box_duplicates <- renderValueBox({
    n_dup <- sum(duplicated(paste(df$Series_Title, df$Released_Year)))
    valueBox(n_dup, "Dubletten (Titel + Jahr)",
             icon = icon("clone"),
             color = ifelse(n_dup > 0, "red", "green"))
  })

  output$box_match_types <- renderValueBox({
    n_types <- if (!is.null(match_quality_df)) nrow(match_quality_df) else NA
    valueBox(n_types, "Match-Typen erkannt",
             icon = icon("link"), color = "yellow")
  })

  output$box_unreliable <- renderValueBox({
    n_unrel <- if ("low_critic_count" %in% names(df)) sum(df$low_critic_count, na.rm = TRUE) else NA
    valueBox(n_unrel, "Potenziell instabile RT-Werte",
             icon = icon("shield-alt"), color = "red")
  })

  # ------------------------------------------
  # DYNAMISCHER INTERPRETATIONSTEXT
  # ------------------------------------------
  output$interpretation_text <- renderUI({
    p_fmt  <- function(p) if (p < 0.001) "< 0.001" else sprintf("%.3f", p)
    ci_fmt <- function(ci) sprintf("[%.3f, %.3f]", ci[1], ci[2])

    tags$div(
      style = "color: #ccc; font-size: 13px; line-height: 1.8;",
      tags$p(
        tags$b(style = paste0("color:", COLORS$audience, ";"),
               paste0("r = ", round(stats$corr_audience, 3))),
        sprintf(" %s, p %s", ci_fmt(stats$ci_audience), p_fmt(stats$p_audience)),
        " \u2014 IMDb-Publikum und RT-Publikum stimmen deutlich \u00fcberein."
      ),
      tags$p(
        tags$b(style = paste0("color:", COLORS$critics, ";"),
               paste0("r = ", round(stats$corr_critics, 3))),
        sprintf(" %s, p %s", ci_fmt(stats$ci_critics), p_fmt(stats$p_critics)),
        " \u2014 IMDb-Publikum und RT-Kritiker weichen stark ab."
      ),
      tags$p(
        tags$b(style = paste0("color:", COLORS$imdb, ";"),
               paste0("r = ", round(stats$corr_cross, 3))),
        sprintf(" %s, p %s", ci_fmt(stats$ci_cross), p_fmt(stats$p_cross)),
        " \u2014 RT-Kritiker und RT-Publikum sind ebenfalls m\u00e4ssig korreliert."
      ),
      tags$hr(style = "border-color:#444"),
      tags$p(
        style = "font-size: 12px; color: #aaa;",
        sprintf("t-Test (H\u2080: \u00d8 Differenz = 0): t = %.2f, p %s, Cohen\u2019s d = %.2f",
                stats$ttest_diff$statistic, p_fmt(stats$ttest_diff$p.value), stats$cohens_d),
        " \u2014 Die Differenz ist statistisch signifikant."
      ),
      tags$hr(style = "border-color:#444"),
      tags$p(
        "Fazit: ", tags$b("Publikumsmeinungen"),
        " konvergieren plattform\u00fcbergreifend. ",
        tags$b("Kritikerurteile"), " weichen systematisch ab."
      )
    )
  })

  # ------------------------------------------
  # PLOT: DISTRIBUTION
  # ------------------------------------------
  output$plot_distribution <- renderPlotly({
    p1 <- ggplot(df, aes(x = IMDB_Rating)) +
      geom_histogram(bins = 15, fill = COLORS$imdb, color = "black", alpha = 0.85) +
      geom_vline(xintercept = mean(df$IMDB_Rating, na.rm = TRUE), linetype = "dashed", color = "white") +
      scale_x_continuous(limits = c(0, 10)) +
      labs(title = "IMDb (Publikum)", x = "Bewertung (0\u201310)", y = "Anzahl Filme") +
      theme_dashboard() +
      theme(plot.title = element_text(color = COLORS$imdb, face = "bold"))

    p2 <- ggplot(df, aes(x = tomatometer_normalized)) +
      geom_histogram(bins = 15, fill = COLORS$critics, color = "black", alpha = 0.85) +
      geom_vline(xintercept = mean(df$tomatometer_normalized, na.rm = TRUE), linetype = "dashed", color = "white") +
      scale_x_continuous(limits = c(0, 10)) +
      labs(title = "Tomatometer (Kritiker, normalisiert)", x = "Bewertung (0\u201310)", y = "") +
      theme_dashboard() +
      theme(plot.title = element_text(color = COLORS$critics, face = "bold"))

    subplot(
      ggplotly(p1, tooltip = c("x", "y")),
      ggplotly(p2, tooltip = c("x", "y")),
      nrows = 1, shareY = FALSE, titleX = TRUE
    ) %>% config(displaylogo = FALSE, responsive = TRUE)
  })

  # ------------------------------------------
  # PLOT: SCATTER MIT TRENDLINIE
  # ------------------------------------------
  output$plot_scatter <- renderPlotly({
    p <- ggplot(
      df,
      aes(
        x = tomatometer_normalized,
        y = IMDB_Rating,
        text = paste0(
          Series_Title, " (", Released_Year, ")",
          "<br>IMDb: ", round(IMDB_Rating, 2),
          "<br>RT Kritiker: ", round(tomatometer_normalized, 2),
          "<br>Differenz: ", round(rating_diff, 2)
        )
      )
    ) +
      geom_point(alpha = 0.45, color = COLORS$imdb, size = 1.8) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = COLORS$critics, alpha = 0.7) +
      geom_smooth(method = "lm", se = FALSE, color = "white", linewidth = 0.7) +
      annotate("text", x = 3.2, y = 9.15, color = "white", size = 3.4,
               label = paste0("Pearson r = ", round(stats$corr_critics, 3))) +
      labs(x = "Tomatometer (normalisiert, 0\u201310)", y = "IMDb Rating (0\u201310)") +
      theme_dashboard()

    ggplotly(p, tooltip = "text") %>%
      config(displaylogo = FALSE, responsive = TRUE)
  })

  # ------------------------------------------
  # TABELLEN: TOP ABWEICHUNGEN (DT statt renderTable)
  # ------------------------------------------
  output$table_top_imdb <- renderDT({
    stats$top5_imdb %>%
      mutate(across(where(is.numeric), ~ round(.x, 2))) %>%
      rename(Film = Series_Title, Jahr = Released_Year,
             IMDb = IMDB_Rating, `RT-Kritiker` = tomatometer_normalized,
             Differenz = rating_diff)
  }, options = list(dom = "t", pageLength = 5), rownames = FALSE)

  output$table_top_rt <- renderDT({
    stats$top5_rt %>%
      mutate(across(where(is.numeric), ~ round(.x, 2))) %>%
      rename(Film = Series_Title, Jahr = Released_Year,
             IMDb = IMDB_Rating, `RT-Kritiker` = tomatometer_normalized,
             Differenz = rating_diff)
  }, options = list(dom = "t", pageLength = 5), rownames = FALSE)

  # ------------------------------------------
  # PLOT: DREI-WEGE SCATTER
  # ------------------------------------------
  output$plot_threeway <- renderPlotly({
    p1 <- plot_ly(
      df, x = ~tomatometer_normalized, y = ~IMDB_Rating,
      type = "scatter", mode = "markers",
      marker = list(color = COLORS$imdb, opacity = 0.45, size = 5),
      name = "IMDb vs. RT-Kritiker",
      text = ~paste0(Series_Title, " (", Released_Year, ")",
                     "<br>IMDb: ", round(IMDB_Rating, 2),
                     "<br>RT Kritiker: ", round(tomatometer_normalized, 2)),
      hoverinfo = "text"
    ) %>%
      add_trace(x = c(0, 10), y = c(0, 10), type = "scatter", mode = "lines",
                line = list(dash = "dash", color = "white", width = 1),
                showlegend = FALSE, inherit = FALSE) %>%
      layout(
        xaxis = list(title = "RT-Kritiker", color = COLORS$text),
        yaxis = list(title = "IMDb", color = COLORS$text),
        annotations = list(list(
          x = 3, y = 9.1,
          text = paste0("r = ", round(stats$corr_critics, 3)),
          showarrow = FALSE, font = list(color = "white", size = 12)
        ))
      )

    p2 <- plot_ly(
      df, x = ~audience_normalized, y = ~IMDB_Rating,
      type = "scatter", mode = "markers",
      marker = list(color = COLORS$audience, opacity = 0.45, size = 5),
      name = "IMDb vs. RT-Publikum",
      text = ~paste0(Series_Title, " (", Released_Year, ")",
                     "<br>IMDb: ", round(IMDB_Rating, 2),
                     "<br>RT Publikum: ", round(audience_normalized, 2)),
      hoverinfo = "text"
    ) %>%
      add_trace(x = c(0, 10), y = c(0, 10), type = "scatter", mode = "lines",
                line = list(dash = "dash", color = "white", width = 1),
                showlegend = FALSE, inherit = FALSE) %>%
      layout(
        xaxis = list(title = "RT-Publikum", color = COLORS$text),
        yaxis = list(title = "", color = COLORS$text),
        annotations = list(list(
          x = 7.5, y = 9.1,
          text = paste0("r = ", round(stats$corr_audience, 3)),
          showarrow = FALSE, font = list(color = COLORS$audience, size = 13)
        ))
      )

    p3 <- plot_ly(
      df, x = ~tomatometer_normalized, y = ~audience_normalized,
      type = "scatter", mode = "markers",
      marker = list(color = COLORS$critics, opacity = 0.45, size = 5),
      name = "RT-Kritiker vs. RT-Publikum",
      text = ~paste0(Series_Title, " (", Released_Year, ")",
                     "<br>RT Kritiker: ", round(tomatometer_normalized, 2),
                     "<br>RT Publikum: ", round(audience_normalized, 2)),
      hoverinfo = "text"
    ) %>%
      add_trace(x = c(0, 10), y = c(0, 10), type = "scatter", mode = "lines",
                line = list(dash = "dash", color = "white", width = 1),
                showlegend = FALSE, inherit = FALSE) %>%
      layout(
        xaxis = list(title = "RT-Kritiker", color = COLORS$text),
        yaxis = list(title = "RT-Publikum", color = COLORS$text),
        annotations = list(list(
          x = 3, y = 9.5,
          text = paste0("r = ", round(stats$corr_cross, 3)),
          showarrow = FALSE, font = list(color = "white", size = 12)
        ))
      )

    subplot(p1, p2, p3, nrows = 1, shareY = FALSE, titleX = TRUE) %>%
      plotly_dark_layout(hovermode = "closest")
  })

  # ------------------------------------------
  # PLOT: DIFFERENZ-BALKEN
  # ------------------------------------------
  output$plot_diff_bars <- renderPlotly({
    diff_df <- data.frame(
      Vergleich = c("IMDb \u2212 RT-Kritiker", "IMDb \u2212 RT-Publikum", "RT-Kritiker \u2212 RT-Publikum"),
      Differenz = c(
        mean(df$IMDB_Rating - df$tomatometer_normalized, na.rm = TRUE),
        mean(df$IMDB_Rating - df$audience_normalized, na.rm = TRUE),
        mean(df$tomatometer_normalized - df$audience_normalized, na.rm = TRUE)
      ),
      Farbe = c(COLORS$critics, COLORS$audience, COLORS$imdb),
      stringsAsFactors = FALSE
    )

    plot_ly(
      diff_df, x = ~Vergleich, y = ~Differenz, type = "bar",
      marker = list(color = diff_df$Farbe, line = list(color = "black", width = 1)),
      text = ~round(Differenz, 2), textposition = "outside"
    ) %>%
      add_segments(x = -0.5, xend = 2.5, y = 0, yend = 0,
                   line = list(dash = "dash", color = "white", width = 1)) %>%
      plotly_dark_layout(
        yaxis = list(title = "\u00d8 Differenz (normalisiert, 0\u201310)"),
        xaxis = list(title = "")
      )
  })

  # ------------------------------------------
  # PLOT: GENRE GROUPED
  # ------------------------------------------
  output$plot_genre_grouped <- renderPlotly({
    gs <- genre_data()
    req(nrow(gs) > 0)
    gs <- gs %>% arrange(avg_imdb)
    gs$primary_genre <- factor(gs$primary_genre, levels = gs$primary_genre)

    plot_ly(gs, x = ~primary_genre) %>%
      add_bars(y = ~avg_imdb,     name = "IMDb (Publikum)",  marker = list(color = COLORS$imdb)) %>%
      add_bars(y = ~avg_critics,  name = "RT-Kritiker",      marker = list(color = COLORS$critics)) %>%
      add_bars(y = ~avg_audience, name = "RT-Publikum",      marker = list(color = COLORS$audience)) %>%
      plotly_dark_layout(
        barmode = "group",
        yaxis = list(title = "\u00d8 Bewertung (0\u201310)", range = c(6.5, 10)),
        xaxis = list(title = "Genre")
      )
  })

  # ------------------------------------------
  # PLOT: GENRE DIFF
  # ------------------------------------------
  output$plot_genre_diff <- renderPlotly({
    gs <- genre_data()
    req(nrow(gs) > 0)
    gs <- gs %>% arrange(avg_diff)
    gs$primary_genre <- factor(gs$primary_genre, levels = gs$primary_genre)
    bar_colors <- ifelse(gs$avg_diff > 0, COLORS$imdb, COLORS$critics)

    plot_ly(
      gs, x = ~avg_diff, y = ~primary_genre, type = "bar", orientation = "h",
      marker = list(color = bar_colors, line = list(color = "black", width = 0.5)),
      text = ~paste0("n=", count, " | Diff=", round(avg_diff, 2)),
      textposition = "outside"
    ) %>%
      add_segments(x = 0, xend = 0, y = 0.5, yend = nrow(gs) + 0.5,
                   line = list(color = "white", width = 1)) %>%
      plotly_dark_layout(
        xaxis = list(title = "\u00d8 IMDb \u2212 \u00d8 Tomatometer (normalisiert)"),
        yaxis = list(title = "")
      )
  })

  # ------------------------------------------
  # PLOT: DECADE
  # ------------------------------------------
  output$plot_decade <- renderPlotly({
    ds <- stats$decade_stats
    req(!is.null(ds), nrow(ds) > 0)

    plot_ly(ds) %>%
      add_trace(
        x = ~decade, y = ~avg_imdb,
        type = "scatter", mode = "lines+markers",
        name = "IMDb (Publikum)",
        line = list(color = COLORS$imdb, width = 2.5),
        marker = list(color = COLORS$imdb, size = 8),
        text = ~paste0(decade, "er | n=", count, "<br>IMDb: ", round(avg_imdb, 2)),
        hoverinfo = "text"
      ) %>%
      add_trace(
        x = ~decade, y = ~avg_critics,
        type = "scatter", mode = "lines+markers",
        name = "RT-Kritiker (normalisiert)",
        line = list(color = COLORS$critics, width = 2.5),
        marker = list(color = COLORS$critics, size = 8),
        text = ~paste0(decade, "er | n=", count, "<br>RT Kritiker: ", round(avg_critics, 2)),
        hoverinfo = "text"
      ) %>%
      plotly_dark_layout(
        yaxis = list(title = "\u00d8 Bewertung (0\u201310)", range = c(6.5, 10.5)),
        xaxis = list(title = "Jahrzehnt"),
        hovermode = "x unified"
      )
  })

  # ------------------------------------------
  # PLOT: VOTES SCATTER (LOG-SKALA)
  # ------------------------------------------
  output$plot_votes_scatter <- renderPlotly({
    p <- ggplot(
      df,
      aes(
        x = votes_log10,
        y = rating_diff,
        color = IMDB_Rating,
        text = paste0(
          Series_Title, " (", Released_Year, ")",
          "<br>IMDb: ", round(IMDB_Rating, 2),
          "<br>Votes: ", comma(No_of_Votes),
          "<br>log10(Votes): ", round(votes_log10, 2),
          "<br>Differenz: ", round(rating_diff, 2)
        )
      )
    ) +
      geom_point(alpha = 0.5, size = 1.7) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "white", alpha = 0.5) +
      geom_smooth(method = "lm", se = FALSE, color = "white", linewidth = 0.7) +
      scale_color_gradient(low = "#2196F3", high = "#FA320A", name = "IMDb") +
      labs(x = "log10(Anzahl IMDb-Votes)", y = "Differenz IMDb \u2212 RT-Kritiker") +
      theme_dashboard()

    ggplotly(p, tooltip = "text") %>%
      config(displaylogo = FALSE, responsive = TRUE)
  })

  # ------------------------------------------
  # PLOT: VOTES BOX
  # ------------------------------------------
  output$plot_votes_box <- renderPlotly({
    plot_ly(
      df, x = ~vote_bucket, y = ~rating_diff, type = "box",
      color = ~vote_bucket,
      colors = c("#d4e6f1", "#85c1e9", "#2e86c1", "#1a5276"),
      text = ~paste0(Series_Title, " (", Released_Year, ")",
                     "<br>Bucket: ", vote_bucket,
                     "<br>Differenz: ", round(rating_diff, 2)),
      hoverinfo = "text"
    ) %>%
      add_segments(x = -0.5, xend = 3.5, y = 0, yend = 0,
                   line = list(dash = "dash", color = "red", width = 1)) %>%
      plotly_dark_layout(
        yaxis = list(title = "Differenz IMDb \u2212 RT-Kritiker"),
        xaxis = list(title = "Vote-Bucket"),
        showlegend = FALSE
      )
  })

  # ------------------------------------------
  # TABLE: VOTES
  # ------------------------------------------
  output$table_votes <- renderDT({
    stats$vote_stats %>%
      mutate(across(where(is.numeric), ~ round(.x, 3))) %>%
      rename(`Vote-Bucket` = vote_bucket, `\u00d8 IMDb` = avg_imdb,
             `\u00d8 Diff (IMDb-RT)` = avg_diff, `Anzahl Filme` = count)
  }, options = list(pageLength = 10, dom = "t"), rownames = FALSE)

  # ------------------------------------------
  # PLOT: RELIABILITY SCATTER
  # ------------------------------------------
  output$plot_reliability <- renderPlotly({
    status_colors <- c(
      "Certified-Fresh" = COLORS$critics,
      "Fresh"           = COLORS$imdb,
      "Rotten"          = COLORS$muted
    )

    p <- ggplot(
      df,
      aes(x = tomatometer_count, y = tomatometer_rating,
          color = tomatometer_status,
          text = paste0(Series_Title, "<br>Kritiken: ", tomatometer_count,
                        "<br>Tomatometer: ", tomatometer_rating, "%"))
    ) +
      geom_point(alpha = 0.5, size = 1.7) +
      geom_vline(xintercept = 20, linetype = "dashed", color = "white") +
      scale_color_manual(values = status_colors, name = "Status") +
      labs(x = "Anzahl Kritikerbesprechungen", y = "Tomatometer Rating (%)") +
      theme_dashboard()

    ggplotly(p, tooltip = "text") %>%
      config(displaylogo = FALSE, responsive = TRUE)
  })

  # ------------------------------------------
  # PLOT: RELIABILITY DIFF (NEU)
  # ------------------------------------------
  output$plot_reliability_diff <- renderPlotly({
    p <- ggplot(
      df,
      aes(x = tomatometer_count, y = abs_rating_diff,
          text = paste0(Series_Title, "<br>Kritiken: ", tomatometer_count,
                        "<br>|IMDb \u2212 RT|: ", round(abs_rating_diff, 2)))
    ) +
      geom_point(alpha = 0.5, size = 1.7, color = COLORS$audience) +
      geom_vline(xintercept = 20, linetype = "dashed", color = "white") +
      geom_smooth(method = "lm", se = FALSE, color = "white", linewidth = 0.7) +
      labs(x = "Anzahl Kritikerbesprechungen", y = "|IMDb \u2212 RT-Kritiker|") +
      theme_dashboard()

    ggplotly(p, tooltip = "text") %>%
      config(displaylogo = FALSE, responsive = TRUE)
  })

  # ------------------------------------------
  # PLOT: STATUS BOXPLOT
  # ------------------------------------------
  output$plot_status_box <- renderPlotly({
    status_order <- c("Certified-Fresh", "Fresh", "Rotten")
    status_cols  <- c(COLORS$critics, COLORS$imdb, COLORS$muted)

    plot_ly(
      df,
      x = ~factor(tomatometer_status, levels = status_order),
      y = ~IMDB_Rating, type = "box",
      color = ~factor(tomatometer_status, levels = status_order),
      colors = status_cols,
      text = ~paste0(Series_Title, "<br>Status: ", tomatometer_status,
                     "<br>IMDb: ", round(IMDB_Rating, 2)),
      hoverinfo = "text"
    ) %>%
      plotly_dark_layout(
        yaxis = list(title = "IMDb Rating"),
        xaxis = list(title = "Tomatometer Status"),
        showlegend = FALSE
      )
  })

  # ------------------------------------------
  # TABLE: LOW CRITICS (DT statt renderTable)
  # ------------------------------------------
  output$table_low_critics <- renderDT({
    req("low_critic_count" %in% names(df))

    df %>%
      filter(low_critic_count) %>%
      select(Series_Title, Released_Year, IMDB_Rating,
             tomatometer_rating, tomatometer_count, rating_diff) %>%
      arrange(tomatometer_count) %>%
      mutate(across(where(is.numeric), ~ round(.x, 2))) %>%
      rename(Film = Series_Title, Jahr = Released_Year,
             `IMDb Rating` = IMDB_Rating, `Tomatometer (%)` = tomatometer_rating,
             `Anzahl Kritiken` = tomatometer_count, `IMDb \u2212 RT` = rating_diff)
  }, options = list(pageLength = 8, scrollX = TRUE), rownames = FALSE)

  # ------------------------------------------
  # DATENQUALIT\u00c4T: TABELLEN
  # ------------------------------------------
  output$table_qa_metrics <- renderDT({
    qa_metrics <- data.frame(
      Kennzahl = c(
        "Zeilen im gemergten Datensatz",
        "Fehlende IMDb-Ratings",
        "Fehlende RT-Kritiker-Werte",
        "Fehlende RT-Publikums-Werte",
        "Doppelte Filmtitel/Jahr-Kombinationen",
        "IMDb Rating Min",
        "IMDb Rating Max",
        "RT-Kritiker normalisiert Min",
        "RT-Kritiker normalisiert Max",
        "Filme mit < 20 Kritiken",
        "Distinct Genres"
      ),
      Wert = c(
        nrow(df),
        sum(is.na(df$IMDB_Rating)),
        sum(is.na(df$tomatometer_normalized)),
        sum(is.na(df$audience_normalized)),
        sum(duplicated(paste(df$Series_Title, df$Released_Year))),
        round(min(df$IMDB_Rating, na.rm = TRUE), 2),
        round(max(df$IMDB_Rating, na.rm = TRUE), 2),
        round(min(df$tomatometer_normalized, na.rm = TRUE), 2),
        round(max(df$tomatometer_normalized, na.rm = TRUE), 2),
        if ("low_critic_count" %in% names(df)) sum(df$low_critic_count, na.rm = TRUE) else NA,
        if ("primary_genre" %in% names(df)) n_distinct(df$primary_genre[!is.na(df$primary_genre)]) else NA
      ),
      stringsAsFactors = FALSE
    )
    qa_metrics
  }, options = list(dom = "t", pageLength = 20), rownames = FALSE)

  output$table_missing <- renderDT({
    qa_missing_df %>% arrange(desc(Fehlende_Werte))
  }, options = list(dom = "t", pageLength = 10), rownames = FALSE)

  # ------------------------------------------
  # DATENQUALIT\u00c4T: FEHLENDE WERTE PLOT
  # ------------------------------------------
  output$plot_missing <- renderPlotly({
    miss_df <- qa_missing_df %>% arrange(Fehlende_Werte)
    miss_df$Variable <- factor(miss_df$Variable, levels = miss_df$Variable)

    plot_ly(
      miss_df, x = ~Fehlende_Werte, y = ~Variable,
      type = "bar", orientation = "h",
      marker = list(color = COLORS$critics),
      text = ~Fehlende_Werte, textposition = "outside"
    ) %>%
      plotly_dark_layout(
        xaxis = list(title = "Anzahl fehlender Werte"),
        yaxis = list(title = "")
      )
  })

  # ------------------------------------------
  # DATENQUALIT\u00c4T: MATCH QUALITY
  # ------------------------------------------
  output$plot_match_quality <- renderPlotly({
    validate(
      need(!is.null(match_quality_df) && nrow(match_quality_df) > 0,
           "Keine Match-Typen im Datensatz vorhanden.")
    )

    plot_ly(
      match_quality_df,
      x = ~`Match-Typ`, y = ~Anzahl,
      type = "bar",
      marker = list(color = COLORS$imdb),
      text = ~Anzahl, textposition = "outside"
    ) %>%
      plotly_dark_layout(
        xaxis = list(title = "Match-Typ"),
        yaxis = list(title = "Anzahl Filme")
      )
  })

  # ------------------------------------------
  # FULL DATA TABLE (mit match_type)
  # ------------------------------------------
  output$full_table <- renderDT({
    df %>%
      select(
        Series_Title, Released_Year, primary_genre, IMDB_Rating,
        tomatometer_normalized, audience_normalized,
        rating_diff, abs_rating_diff, tomatometer_count,
        tomatometer_status, No_of_Votes,
        any_of(c("match_type"))
      ) %>%
      mutate(across(where(is.numeric), ~ round(.x, 2))) %>%
      rename(
        Film          = Series_Title,
        Jahr          = Released_Year,
        Genre         = primary_genre,
        IMDb          = IMDB_Rating,
        `RT-Kritiker` = tomatometer_normalized,
        `RT-Publikum` = audience_normalized,
        Differenz     = rating_diff,
        `|Differenz|` = abs_rating_diff,
        `Anz. Kritiken` = tomatometer_count,
        Status        = tomatometer_status,
        Votes         = No_of_Votes
      )
  },
  filter = "top",
  options = list(pageLength = 15, scrollX = TRUE),
  rownames = FALSE)
}

# ==========================================
# APP STARTEN
# ==========================================
shinyApp(ui = ui, server = server)
