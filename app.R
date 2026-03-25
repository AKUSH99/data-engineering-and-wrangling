# =============================================================
#  IMDb vs. Rotten Tomatoes – Shiny Dashboard
#  FHNW Datenprojekt
#  Starten: shiny::runApp("app.R")  oder  Run App in RStudio
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
# DATEN LADEN (einmalig beim App-Start)
# ==========================================
result <- run_pipeline()
df     <- result$data
stats  <- result$stats

# Farben konsistent mit Python-Version
COL_IMDB     <- "#F5C518"
COL_CRITICS  <- "#FA320A"
COL_AUDIENCE <- "#4A90D9"

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
      menuItem("Übersicht",         tabName = "overview",   icon = icon("chart-bar")),
      menuItem("Drei-Wege-Vergleich", tabName = "threeway", icon = icon("layer-group")),
      menuItem("Genre-Analyse",     tabName = "genre",      icon = icon("film")),
      menuItem("Zeittrend",         tabName = "decade",     icon = icon("clock")),
      menuItem("Popularität",       tabName = "popularity", icon = icon("star")),
      menuItem("Zuverlässigkeit",   tabName = "reliability",icon = icon("check-circle")),
      menuItem("Datentabelle",      tabName = "table",      icon = icon("table"))
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

      /* === TABS (z.B. IMDb >> RT / RT >> IMDb) === */
      .nav-tabs { border-bottom-color: #444; }
      .nav-tabs > li > a { color: #aaa; background-color: #16213e; border-color: #333; }
      .nav-tabs > li > a:hover { color: #fff; background-color: #1a1a2e; border-color: #555; }
      .nav-tabs > li.active > a,
      .nav-tabs > li.active > a:hover,
      .nav-tabs > li.active > a:focus { color: #F5C518 !important; background-color: #1a1a2e !important; border-color: #444; border-bottom-color: #1a1a2e; }
      .tab-content { background-color: transparent; }
      .nav-tabs-custom { background-color: transparent; }
      .nav-tabs-custom > .nav-tabs > li.active > a { color: #F5C518; }

      /* === TABELLEN (renderTable) === */
      .table { color: #ddd; background-color: #16213e; }
      .table-striped > tbody > tr:nth-of-type(odd) { background-color: #1a2240; }
      .table-striped > tbody > tr:nth-of-type(even) { background-color: #16213e; }
      .table-bordered { border-color: #333; }
      .table-bordered > thead > tr > th,
      .table-bordered > tbody > tr > td { border-color: #333; }
      .table > thead > tr > th { color: #F5C518; background-color: #0f0f23; border-bottom-color: #444; }

      /* === DT-DATENTABELLEN === */
      .dataTables_wrapper { color: #ccc; }
      .dataTables_wrapper .dataTables_length,
      .dataTables_wrapper .dataTables_filter,
      .dataTables_wrapper .dataTables_info,
      .dataTables_wrapper .dataTables_paginate { color: #ccc !important; }
      .dataTables_wrapper .dataTables_filter input,
      .dataTables_wrapper .dataTables_length select { color: #ddd; background-color: #1a1a2e; border: 1px solid #444; }
      table.dataTable thead { color: #F5C518; }
      table.dataTable thead th { background-color: #0f0f23 !important; }
      table.dataTable tbody td { color: #ddd; }
      table.dataTable tbody tr { background-color: #16213e !important; }
      table.dataTable tbody tr:hover { background-color: #1e2d50 !important; }
      .dataTables_wrapper .dataTables_paginate .paginate_button { color: #ccc !important; background-color: #16213e !important; border-color: #444 !important; }
      .dataTables_wrapper .dataTables_paginate .paginate_button.current { color: #F5C518 !important; background: #1a1a2e !important; }
      /* DT Spaltenfilter (filter = 'top') */
      table.dataTable thead .dataTables_filter input,
      table.dataTable tfoot input,
      .dataTables_wrapper thead input,
      .dataTables_wrapper thead select { color: #ddd !important; background-color: #1a1a2e !important; border: 1px solid #444 !important; }

      /* === FORM-ELEMENTE (Dropdowns, Inputs) === */
      .form-control { color: #ddd; background-color: #1a1a2e; border: 1px solid #444; }
      .selectize-input { color: #ddd !important; background-color: #1a1a2e !important; border-color: #444 !important; }
      .selectize-input.focus { border-color: #F5C518 !important; }
      .selectize-dropdown { color: #ddd; background-color: #16213e; border-color: #444; }
      .selectize-dropdown .active { background-color: #F5C518 !important; color: #000 !important; }
      .selectize-dropdown-content .option { color: #ddd; }
      .selectize-input .item { color: #ddd !important; }
      .selectize-input .remove { color: #FA320A !important; font-weight: bold; }
      .control-label { color: #ccc !important; }

      /* === HEADER-ELEMENTE === */
      .skin-black .main-header .navbar .sidebar-toggle { color: #ccc !important; }
      .skin-black .main-header .navbar .sidebar-toggle:hover { color: #F5C518 !important; background-color: #16213e !important; }
      .skin-black .main-header .navbar .nav > li > a { color: #ccc !important; }
      .skin-black .main-header .navbar .nav > li > a:hover { color: #fff !important; }

      /* === BOX-TITEL === */
      .box-title { color: #F5C518 !important; }

      /* === PLOTLY MODEBAR === */
      .modebar-btn { fill: #aaa !important; }
      .modebar-btn:hover { fill: #F5C518 !important; }
      .modebar-group { background-color: transparent !important; }
    "))),

    tabItems(

      # ==========================================
      # TAB 1: ÜBERSICHT
      # ==========================================
      tabItem(tabName = "overview",
        fluidRow(
          valueBoxOutput("box_total",    width = 3),
          valueBoxOutput("box_corr",     width = 3),
          valueBoxOutput("box_avg_diff", width = 3),
          valueBoxOutput("box_bias",     width = 3)
        ),
        fluidRow(
          box(title = "Bewertungsverteilung: IMDb vs. Tomatometer",
              width = 8, solidHeader = TRUE,
              plotlyOutput("plot_distribution", height = "350px")),
          box(title = "Selektionsbias Hinweis", width = 4, solidHeader = TRUE,
              tags$div(style = "color: #ccc; font-size: 13px; line-height: 1.7;",
                tags$p(icon("exclamation-triangle", style="color:#FA320A"),
                  " Der IMDb-Datensatz enthält nur die ", tags$b("Top 1000"), " Filme."),
                tags$hr(style="border-color:#444"),
                tags$p("IMDb-Ratings: ", tags$b(paste0(
                  round(min(df$IMDB_Rating), 1), " \u2013 ", round(max(df$IMDB_Rating), 1))),
                  " (nicht 1\u201310)"),
                tags$p("RT-Scores hoch, weil Top-1000-Filme auch von Kritikern \u00fcberdurchschnittlich bewertet werden."),
                tags$p(tags$b(paste0(round(mean(df$tomatometer_normalized >= 9) * 100), "%")),
                  " der Filme haben Tomatometer \u2265 90%"),
                tags$hr(style="border-color:#444"),
                tags$p(style="color:#aaa; font-size:12px;",
                  "Die Ergebnisse beschreiben das Bewertungsverhalten für überdurchschnittlich gute Publikumsfilme, nicht den Gesamtmarkt.")
              )
          )
        ),
        fluidRow(
          box(title = "Streudiagramm IMDb vs. Tomatometer",
              width = 6, solidHeader = TRUE,
              plotlyOutput("plot_scatter", height = "350px")),
          box(title = "Top 5: Grösste Abweichungen",
              width = 6, solidHeader = TRUE,
              tabsetPanel(
                tabPanel("IMDb >> RT",
                  tableOutput("table_top_imdb")
                ),
                tabPanel("RT >> IMDb",
                  tableOutput("table_top_rt")
                )
              )
          )
        )
      ),

      # ==========================================
      # TAB 2: DREI-WEGE-VERGLEICH
      # ==========================================
      tabItem(tabName = "threeway",
        fluidRow(
          infoBoxOutput("corr_critics_box",  width = 4),
          infoBoxOutput("corr_audience_box", width = 4),
          infoBoxOutput("corr_cross_box",    width = 4)
        ),
        fluidRow(
          box(title = "IMDb vs. RT-Kritiker vs. RT-Publikum",
              width = 12, solidHeader = TRUE,
              plotlyOutput("plot_threeway", height = "400px"))
        ),
        fluidRow(
          box(title = "Ø Differenzen im Vergleich",
              width = 6, solidHeader = TRUE,
              plotlyOutput("plot_diff_bars", height = "300px")),
          box(title = "Interpretation", width = 6, solidHeader = TRUE,
              uiOutput("interpretation_text")
          )
        )
      ),

      # ==========================================
      # TAB 3: GENRE-ANALYSE
      # ==========================================
      tabItem(tabName = "genre",
        fluidRow(
          box(width = 12,
              selectInput("genre_filter", "Genre filtern:",
                          choices = c("Alle Genres" = "all"),
                          multiple = TRUE, width = "100%")
          )
        ),
        fluidRow(
          box(title = "Bewertung nach Genre – Drei Plattformen",
              width = 12, solidHeader = TRUE,
              plotlyOutput("plot_genre_grouped", height = "420px"))
        ),
        fluidRow(
          box(title = "Bewertungsdifferenz nach Genre (IMDb − RT-Kritiker)",
              width = 12, solidHeader = TRUE,
              plotlyOutput("plot_genre_diff", height = "350px"))
        )
      ),

      # ==========================================
      # TAB 4: ZEITTREND
      # ==========================================
      tabItem(tabName = "decade",
        fluidRow(
          box(title = "Bewertungstrend nach Jahrzehnt (ab 1960er, n ≥ 48)",
              width = 12, solidHeader = TRUE,
              plotlyOutput("plot_decade", height = "420px")),
          box(width = 12, solidHeader = FALSE,
              tags$div(style = "color: #aaa; font-size: 12px;",
                icon("exclamation-triangle", style="color:#FA320A"),
                " Jahrzehnte vor 1960 ausgeblendet: Die wenigen gematchten Altfilme (z.B. Chaplin, Metropolis) sind nicht repräsentativ für die jeweilige Epoche (n < 48)."
              )
          )
        )
      ),

      # ==========================================
      # TAB 5: POPULARITÄT
      # ==========================================
      tabItem(tabName = "popularity",
        fluidRow(
          box(title = "IMDb-Votes vs. Bewertungsdifferenz",
              width = 7, solidHeader = TRUE,
              plotlyOutput("plot_votes_scatter", height = "380px")),
          box(title = "Bewertungslücke nach Popularitäts-Bucket",
              width = 5, solidHeader = TRUE,
              plotlyOutput("plot_votes_box", height = "380px"))
        ),
        fluidRow(
          box(title = "Popularitäts-Statistik", width = 12, solidHeader = TRUE,
              DT::dataTableOutput("table_votes"))
        )
      ),

      # ==========================================
      # TAB 6: ZUVERLÄSSIGKEIT
      # ==========================================
      tabItem(tabName = "reliability",
        fluidRow(
          valueBoxOutput("box_median_critics", width = 4),
          valueBoxOutput("box_low_critics",    width = 4),
          valueBoxOutput("box_certified",      width = 4)
        ),
        fluidRow(
          box(title = "Kritikanzahl vs. Tomatometer-Rating",
              width = 7, solidHeader = TRUE,
              plotlyOutput("plot_reliability", height = "380px")),
          box(title = "IMDb Rating nach Tomatometer-Status",
              width = 5, solidHeader = TRUE,
              plotlyOutput("plot_status_box", height = "380px"))
        ),
        fluidRow(
          box(title = "Filme mit < 20 Kritikerbesprechungen (geflaggt)",
              width = 12, solidHeader = TRUE,
              tableOutput("table_low_critics"))
        )
      ),

      # ==========================================
      # TAB 7: DATENTABELLE
      # ==========================================
      tabItem(tabName = "table",
        fluidRow(
          box(title = uiOutput("table_title", inline = TRUE),
              width = 12, solidHeader = TRUE,
              DT::dataTableOutput("full_table"))
        )
      )
    )
  )
)


# ==========================================
# SERVER
# ==========================================
server <- function(input, output, session) {

  # --- VALUE BOXES ---
  output$box_total <- renderValueBox({
    valueBox(stats$n_total, "Analysierte Filme", icon = icon("film"),
             color = "yellow")
  })
  output$box_corr <- renderValueBox({
    valueBox(round(stats$corr_critics, 3), "Pearson r (IMDb vs. RT-Kritiker)",
             icon = icon("chart-line"), color = "red")
  })
  output$box_avg_diff <- renderValueBox({
    valueBox(round(stats$avg_diff, 3), "Ø Differenz (IMDb − RT)",
             icon = icon("arrows-alt-v"), color = "orange")
  })
  output$box_bias <- renderValueBox({
    valueBox("Top 1000", "Selektionsbias IMDb", icon = icon("exclamation-triangle"),
             color = "red")
  })

  # --- INFO BOXES DREI-WEGE ---
  output$corr_critics_box <- renderInfoBox({
    infoBox("IMDb vs. RT-Kritiker", round(stats$corr_critics, 3),
            icon = icon("user-tie"), color = "red",
            subtitle = "schwache Korrelation")
  })
  output$corr_audience_box <- renderInfoBox({
    infoBox("IMDb vs. RT-Publikum", round(stats$corr_audience, 3),
            icon = icon("users"), color = "blue",
            subtitle = "deutlich stärker!")
  })
  output$corr_cross_box <- renderInfoBox({
    infoBox("RT-Kritiker vs. RT-Publikum", round(stats$corr_cross, 3),
            icon = icon("exchange-alt"), color = "yellow",
            subtitle = "mittlere Korrelation")
  })

  # --- DYNAMISCHER INTERPRETATION-TEXT (mit Konfidenzintervallen und p-Werten) ---
  output$interpretation_text <- renderUI({
    p_fmt <- function(p) if (p < 0.001) "< 0.001" else sprintf("%.3f", p)
    ci_fmt <- function(ci) sprintf("[%.3f, %.3f]", ci[1], ci[2])

    tags$div(style = "color: #ccc; font-size: 13px; line-height: 1.8;",
      tags$p(tags$b(style="color:#4A90D9", paste0("r = ", round(stats$corr_audience, 3))),
        sprintf(" %s, p %s", ci_fmt(stats$ci_audience), p_fmt(stats$p_audience)),
        " — IMDb-Publikum und RT-Publikum stimmen deutlich überein."),
      tags$p(tags$b(style="color:#FA320A", paste0("r = ", round(stats$corr_critics, 3))),
        sprintf(" %s, p %s", ci_fmt(stats$ci_critics), p_fmt(stats$p_critics)),
        " — IMDb-Publikum und RT-Kritiker weichen stark ab."),
      tags$p(tags$b(style="color:#F5C518", paste0("r = ", round(stats$corr_cross, 3))),
        sprintf(" %s, p %s", ci_fmt(stats$ci_cross), p_fmt(stats$p_cross)),
        " — RT-Kritiker und RT-Publikum sind ebenfalls mässig korreliert."),
      tags$hr(style="border-color:#444"),
      tags$p(style="font-size: 12px; color: #aaa;",
        sprintf("t-Test (H0: Ø Differenz = 0): t = %.2f, p %s, Cohen's d = %.2f",
                stats$ttest_diff$statistic, p_fmt(stats$ttest_diff$p.value), stats$cohens_d),
        " — Die Differenz ist statistisch signifikant."),
      tags$hr(style="border-color:#444"),
      tags$p("Fazit: ", tags$b("Publikumsmeinungen"),
        " konvergieren plattformübergreifend. ",
        tags$b("Kritikerurteile"), " weichen systematisch ab.")
    )
  })

  # --- DYNAMISCHER TABELLEN-TITEL ---
  output$table_title <- renderUI({
    paste0("Vollständiger gemergter Datensatz (", nrow(df), " Filme)")
  })

  # --- GENRE-FILTER INITIALISIERUNG ---
  observe({
    genres <- sort(unique(stats$genre_stats$primary_genre))
    updateSelectInput(session, "genre_filter",
                      choices = c("Alle Genres" = "all", setNames(genres, genres)))
  })

  # --- RELIABILITY BOXES ---
  output$box_median_critics <- renderValueBox({
    valueBox(median(df$tomatometer_count, na.rm = TRUE),
             "Median Kritikanzahl", icon = icon("newspaper"), color = "yellow")
  })
  output$box_low_critics <- renderValueBox({
    valueBox(stats$low_critics, "Filme < 20 Kritiken (geflaggt)",
             icon = icon("flag"), color = "red")
  })
  output$box_certified <- renderValueBox({
    n_cert <- sum(df$tomatometer_status == "Certified-Fresh", na.rm = TRUE)
    valueBox(n_cert, "Certified-Fresh Filme",
             icon = icon("certificate"), color = "green")
  })

  # --- PLOT: DISTRIBUTION ---
  output$plot_distribution <- renderPlotly({
    p1 <- ggplot(df, aes(x = IMDB_Rating)) +
      geom_histogram(bins = 15, fill = COL_IMDB, color = "black", alpha = 0.85) +
      geom_vline(xintercept = mean(df$IMDB_Rating), linetype = "dashed", color = "white") +
      scale_x_continuous(limits = c(0, 10)) +
      labs(title = "IMDb (Publikum)", x = "Bewertung (0–10)", y = "Anzahl Filme") +
      theme_dark() +
      theme(plot.title = element_text(color = COL_IMDB, face = "bold"),
            plot.background = element_rect(fill = "#16213e"),
            panel.background = element_rect(fill = "#16213e"),
            text = element_text(color = "#ccc"))

    p2 <- ggplot(df, aes(x = tomatometer_normalized)) +
      geom_histogram(bins = 15, fill = COL_CRITICS, color = "black", alpha = 0.85) +
      geom_vline(xintercept = mean(df$tomatometer_normalized), linetype = "dashed", color = "white") +
      scale_x_continuous(limits = c(0, 10)) +
      labs(title = "Tomatometer (Kritiker, normalisiert)", x = "Bewertung (0–10)", y = "") +
      theme_dark() +
      theme(plot.title = element_text(color = COL_CRITICS, face = "bold"),
            plot.background = element_rect(fill = "#16213e"),
            panel.background = element_rect(fill = "#16213e"),
            text = element_text(color = "#ccc"))

    subplot(ggplotly(p1), ggplotly(p2), nrows = 1, shareY = FALSE, titleX = TRUE)
  })

  # --- PLOT: SCATTER ---
  output$plot_scatter <- renderPlotly({
    p <- ggplot(df, aes(x = tomatometer_normalized, y = IMDB_Rating,
                        text = paste0(Series_Title, " (", Released_Year, ")"))) +
      geom_point(alpha = 0.45, color = COL_IMDB, size = 1.5) +
      geom_abline(slope = 1, intercept = 0, linetype = "dashed", color = "red", alpha = 0.6) +
      annotate("text", x = 3, y = 9.1, color = "white", size = 3,
               label = paste0("Pearson r = ", round(stats$corr_critics, 3))) +
      labs(x = "Tomatometer (normalisiert, 0–10)", y = "IMDb Rating (0–10)") +
      theme_dark() +
      theme(plot.background  = element_rect(fill = "#16213e"),
            panel.background = element_rect(fill = "#16213e"),
            text = element_text(color = "#ccc"))
    ggplotly(p, tooltip = "text")
  })

  # --- TABLES: TOP ABWEICHUNGEN ---
  output$table_top_imdb <- renderTable({
    stats$top5_imdb %>%
      mutate(across(where(is.numeric), ~round(.x, 2))) %>%
      rename(Film = Series_Title, Jahr = Released_Year,
             IMDb = IMDB_Rating, RT = tomatometer_normalized, Diff = rating_diff)
  }, striped = TRUE, bordered = TRUE)

  output$table_top_rt <- renderTable({
    stats$top5_rt %>%
      mutate(across(where(is.numeric), ~round(.x, 2))) %>%
      rename(Film = Series_Title, Jahr = Released_Year,
             IMDb = IMDB_Rating, RT = tomatometer_normalized, Diff = rating_diff)
  }, striped = TRUE, bordered = TRUE)

  # --- PLOT: DREI-WEGE SCATTER ---
  output$plot_threeway <- renderPlotly({
    p1 <- plot_ly(df, x = ~tomatometer_normalized, y = ~IMDB_Rating,
                  type = "scatter", mode = "markers",
                  marker = list(color = COL_IMDB, opacity = 0.4, size = 5),
                  name = "IMDb vs. RT-Kritiker",
                  text = ~paste0(Series_Title, " (", Released_Year, ")")) %>%
      add_trace(x = c(0,10), y = c(0,10), type = "scatter", mode = "lines",
                line = list(dash = "dash", color = "white", width = 1),
                name = "Perfekte Übereinstimmung", showlegend = FALSE, inherit = FALSE) %>%
      layout(xaxis = list(title = "RT-Kritiker", color = "#ccc"),
             yaxis = list(title = "IMDb", color = "#ccc"),
             paper_bgcolor = "#16213e", plot_bgcolor = "#16213e",
             font = list(color = "#ccc"),
             annotations = list(list(x=3, y=9.1, text=paste0("r = ", round(stats$corr_critics,3)),
                                     showarrow=FALSE, font=list(color="white", size=12))))

    p2 <- plot_ly(df, x = ~audience_normalized, y = ~IMDB_Rating,
                  type = "scatter", mode = "markers",
                  marker = list(color = COL_AUDIENCE, opacity = 0.4, size = 5),
                  name = "IMDb vs. RT-Publikum",
                  text = ~paste0(Series_Title, " (", Released_Year, ")")) %>%
      add_trace(x = c(0,10), y = c(0,10), type = "scatter", mode = "lines",
                line = list(dash = "dash", color = "white", width = 1),
                showlegend = FALSE, inherit = FALSE) %>%
      layout(xaxis = list(title = "RT-Publikum", color = "#ccc"),
             yaxis = list(title = "", color = "#ccc"),
             paper_bgcolor = "#16213e", plot_bgcolor = "#16213e",
             font = list(color = "#ccc"),
             annotations = list(list(x=7.5, y=9.1, text=paste0("r = ", round(stats$corr_audience,3)),
                                     showarrow=FALSE, font=list(color=COL_AUDIENCE, size=13))))

    p3 <- plot_ly(df, x = ~tomatometer_normalized, y = ~audience_normalized,
                  type = "scatter", mode = "markers",
                  marker = list(color = COL_CRITICS, opacity = 0.4, size = 5),
                  name = "RT-Kritiker vs. RT-Publikum",
                  text = ~paste0(Series_Title, " (", Released_Year, ")")) %>%
      add_trace(x = c(0,10), y = c(0,10), type = "scatter", mode = "lines",
                line = list(dash = "dash", color = "white", width = 1),
                showlegend = FALSE, inherit = FALSE) %>%
      layout(xaxis = list(title = "RT-Kritiker", color = "#ccc"),
             yaxis = list(title = "RT-Publikum", color = "#ccc"),
             paper_bgcolor = "#16213e", plot_bgcolor = "#16213e",
             font = list(color = "#ccc"),
             annotations = list(list(x=3, y=9.5, text=paste0("r = ", round(stats$corr_cross,3)),
                                     showarrow=FALSE, font=list(color="white", size=12))))

    subplot(p1, p2, p3, nrows = 1, shareY = FALSE, titleX = TRUE)
  })

  # --- PLOT: DIFFERENZ-BALKEN ---
  output$plot_diff_bars <- renderPlotly({
    diff_df <- data.frame(
      Vergleich = c("IMDb − RT-Kritiker", "IMDb − RT-Publikum", "RT-Kritiker − RT-Publikum"),
      Differenz = c(mean(df$IMDB_Rating - df$tomatometer_normalized),
                    mean(df$IMDB_Rating - df$audience_normalized),
                    mean(df$tomatometer_normalized - df$audience_normalized)),
      Farbe = c(COL_CRITICS, COL_AUDIENCE, COL_IMDB)
    )
    plot_ly(diff_df, x = ~Vergleich, y = ~Differenz, type = "bar",
            marker = list(color = diff_df$Farbe, line = list(color = "black", width = 1))) %>%
      add_segments(x = -0.5, xend = 2.5, y = 0, yend = 0,
                   line = list(dash = "dash", color = "white", width = 1)) %>%
      layout(paper_bgcolor = "#16213e", plot_bgcolor = "#16213e",
             font = list(color = "#ccc"),
             yaxis = list(title = "Ø Differenz (normalisiert, 0–10)"),
             xaxis = list(title = ""))
  })

  # --- REAKTIVE GENRE-DATEN (gefiltert) ---
  genre_data <- reactive({
    gs <- stats$genre_stats
    sel <- input$genre_filter
    if (!is.null(sel) && !("all" %in% sel)) {
      gs <- gs %>% filter(primary_genre %in% sel)
    }
    gs
  })

  # --- PLOT: GENRE GROUPED ---
  output$plot_genre_grouped <- renderPlotly({
    gs <- genre_data() %>% arrange(avg_imdb)
    gs$primary_genre <- factor(gs$primary_genre, levels = gs$primary_genre)

    plot_ly(gs, x = ~primary_genre) %>%
      add_bars(y = ~avg_imdb,    name = "IMDb (Publikum)",       marker = list(color = COL_IMDB)) %>%
      add_bars(y = ~avg_critics, name = "RT-Kritiker",           marker = list(color = COL_CRITICS)) %>%
      add_bars(y = ~avg_audience,name = "RT-Publikum",           marker = list(color = COL_AUDIENCE)) %>%
      layout(barmode = "group",
             paper_bgcolor = "#16213e", plot_bgcolor = "#16213e",
             font = list(color = "#ccc"),
             yaxis = list(title = "Ø Bewertung (0–10)", range = c(6.5, 10)),
             xaxis = list(title = "Genre"))
  })

  # --- PLOT: GENRE DIFF ---
  output$plot_genre_diff <- renderPlotly({
    gs <- genre_data() %>% arrange(avg_diff)
    gs$primary_genre <- factor(gs$primary_genre, levels = gs$primary_genre)
    bar_colors <- ifelse(gs$avg_diff > 0, COL_IMDB, COL_CRITICS)

    plot_ly(gs, x = ~avg_diff, y = ~primary_genre, type = "bar",
            orientation = "h",
            marker = list(color = bar_colors, line = list(color = "black", width = 0.5)),
            text = ~paste0("n=", count), textposition = "outside") %>%
      add_segments(x = 0, xend = 0, y = 0.5, yend = nrow(gs) + 0.5,
                   line = list(color = "white", width = 1)) %>%
      layout(paper_bgcolor = "#16213e", plot_bgcolor = "#16213e",
             font = list(color = "#ccc"),
             xaxis = list(title = "Ø IMDb − Ø Tomatometer (normalisiert)"),
             yaxis = list(title = ""))
  })

  # --- PLOT: DECADE ---
  output$plot_decade <- renderPlotly({
    ds <- stats$decade_stats
    plot_ly(ds) %>%
      add_trace(x = ~decade, y = ~avg_imdb, type = "scatter", mode = "lines+markers",
                name = "IMDb (Publikum)",
                line = list(color = COL_IMDB, width = 2.5),
                marker = list(color = COL_IMDB, size = 8),
                text = ~paste0(decade, "er | n=", count), hoverinfo = "text+y") %>%
      add_trace(x = ~decade, y = ~avg_critics, type = "scatter", mode = "lines+markers",
                name = "RT-Kritiker (normalisiert)",
                line = list(color = COL_CRITICS, width = 2.5),
                marker = list(color = COL_CRITICS, size = 8),
                text = ~paste0(decade, "er | n=", count), hoverinfo = "text+y") %>%
      layout(paper_bgcolor = "#16213e", plot_bgcolor = "#16213e",
             font = list(color = "#ccc"),
             yaxis = list(title = "Ø Bewertung (0–10)", range = c(6.5, 10.5)),
             xaxis = list(title = "Jahrzehnt"),
             hovermode = "x unified")
  })

  # --- PLOT: VOTES SCATTER ---
  output$plot_votes_scatter <- renderPlotly({
    p <- ggplot(df, aes(x = No_of_Votes / 1e6, y = rating_diff,
                        color = IMDB_Rating,
                        text = paste0(Series_Title, " (", Released_Year, ")"))) +
      geom_point(alpha = 0.45, size = 1.5) +
      geom_hline(yintercept = 0, linetype = "dashed", color = "white", alpha = 0.5) +
      scale_color_gradient(low = "#2196F3", high = "#FA320A", name = "IMDb") +
      labs(x = "Anzahl IMDb-Votes (Mio.)", y = "Differenz IMDb − RT-Kritiker") +
      theme_dark() +
      theme(plot.background  = element_rect(fill = "#16213e"),
            panel.background = element_rect(fill = "#16213e"),
            text = element_text(color = "#ccc"))
    ggplotly(p, tooltip = "text")
  })

  # --- PLOT: VOTES BOX ---
  output$plot_votes_box <- renderPlotly({
    plot_ly(df, x = ~vote_bucket, y = ~rating_diff, type = "box",
            color = ~vote_bucket,
            colors = c("#d4e6f1","#85c1e9","#2e86c1","#1a5276")) %>%
      add_segments(x = -0.5, xend = 3.5, y = 0, yend = 0,
                   line = list(dash = "dash", color = "red", width = 1)) %>%
      layout(paper_bgcolor = "#16213e", plot_bgcolor = "#16213e",
             font = list(color = "#ccc"),
             yaxis = list(title = "Differenz IMDb − RT-Kritiker"),
             xaxis = list(title = "Vote-Bucket"),
             showlegend = FALSE)
  })

  # --- TABLE: VOTES ---
  output$table_votes <- DT::renderDataTable({
    stats$vote_stats %>%
      mutate(across(where(is.numeric), ~round(.x, 3))) %>%
      rename("Vote-Bucket" = vote_bucket, "Ø IMDb" = avg_imdb,
             "Ø Diff (IMDb-RT)" = avg_diff, "Anzahl Filme" = count)
  }, options = list(pageLength = 10, dom = "t"), rownames = FALSE)

  # --- PLOT: RELIABILITY SCATTER ---
  output$plot_reliability <- renderPlotly({
    status_colors <- c("Certified-Fresh" = COL_CRITICS,
                       "Fresh" = COL_IMDB,
                       "Rotten" = "#888888")
    p <- ggplot(df, aes(x = tomatometer_count, y = tomatometer_rating,
                        color = tomatometer_status,
                        text = paste0(Series_Title, "\nKritiken: ", tomatometer_count))) +
      geom_point(alpha = 0.5, size = 1.5) +
      geom_vline(xintercept = 20, linetype = "dashed", color = "white") +
      scale_color_manual(values = status_colors, name = "Status") +
      labs(x = "Anzahl Kritikerbesprechungen", y = "Tomatometer Rating (%)") +
      theme_dark() +
      theme(plot.background  = element_rect(fill = "#16213e"),
            panel.background = element_rect(fill = "#16213e"),
            text = element_text(color = "#ccc"),
            legend.background = element_rect(fill = "#16213e"),
            legend.key = element_rect(fill = "#16213e"))
    ggplotly(p, tooltip = "text")
  })

  # --- PLOT: STATUS BOXPLOT ---
  output$plot_status_box <- renderPlotly({
    status_order <- c("Certified-Fresh", "Fresh", "Rotten")
    status_cols  <- c(COL_CRITICS, COL_IMDB, "#888888")

    plot_ly(df, x = ~factor(tomatometer_status, levels = status_order),
            y = ~IMDB_Rating, type = "box",
            color = ~factor(tomatometer_status, levels = status_order),
            colors = status_cols) %>%
      layout(paper_bgcolor = "#16213e", plot_bgcolor = "#16213e",
             font = list(color = "#ccc"),
             yaxis = list(title = "IMDb Rating"),
             xaxis = list(title = "Tomatometer Status"),
             showlegend = FALSE)
  })

  # --- TABLE: LOW CRITICS ---
  output$table_low_critics <- renderTable({
    df %>%
      filter(low_critic_count) %>%
      select(Series_Title, Released_Year, IMDB_Rating,
             tomatometer_rating, tomatometer_count) %>%
      arrange(tomatometer_count) %>%
      mutate(across(where(is.numeric), ~round(.x, 1))) %>%
      rename(Film = Series_Title, Jahr = Released_Year,
             `IMDb Rating` = IMDB_Rating,
             `Tomatometer (%)` = tomatometer_rating,
             `Anzahl Kritiken` = tomatometer_count)
  }, striped = TRUE, bordered = TRUE)

  # --- FULL DATA TABLE ---
  output$full_table <- DT::renderDataTable({
    df %>%
      select(Series_Title, Released_Year, primary_genre, IMDB_Rating,
             tomatometer_normalized, audience_normalized,
             rating_diff, tomatometer_count, tomatometer_status, No_of_Votes) %>%
      mutate(across(where(is.numeric), ~round(.x, 2))) %>%
      rename(
        Film          = Series_Title,
        Jahr          = Released_Year,
        Genre         = primary_genre,
        IMDb          = IMDB_Rating,
        `RT-Kritiker` = tomatometer_normalized,
        `RT-Publikum` = audience_normalized,
        `Differenz`   = rating_diff,
        `Anz. Kritiken` = tomatometer_count,
        Status        = tomatometer_status,
        Votes         = No_of_Votes
      )
  }, filter = "top",
     options = list(pageLength = 15, scrollX = TRUE),
     rownames = FALSE)
}

# ==========================================
# APP STARTEN
# ==========================================
shinyApp(ui = ui, server = server)
