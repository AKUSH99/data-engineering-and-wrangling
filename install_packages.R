# =============================================================
#  Packages installieren – einmalig ausführen vor dem ersten Start
#  In RStudio: dieses Script öffnen und auf "Source" klicken
# =============================================================

packages <- c(
  "shiny",
  "shinydashboard",
  "tidyverse",
  "ggplot2",
  "dplyr",
  "readr",
  "tidyr",
  "stringr",
  "scales",
  "DT",
  "plotly",
  "RColorBrewer"
)

cat("Prüfe und installiere fehlende Packages...\n\n")

for (pkg in packages) {
  if (!requireNamespace(pkg, quietly = TRUE)) {
    cat(sprintf("  Installiere: %s\n", pkg))
    install.packages(pkg, repos = "https://cran.rstudio.com/")
  } else {
    cat(sprintf("  OK:          %s\n", pkg))
  }
}

cat("\n✓ Alle Packages bereit. Du kannst jetzt app.R starten.\n")
