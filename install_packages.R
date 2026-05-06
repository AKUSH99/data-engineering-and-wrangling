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
  "stringdist",
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

# -------------------------------------------------------------
# Reproduzierbarkeits-Snapshot: sessionInfo() persistieren
# Schreibt R-Version, Plattform, Locale und exakte Package-
# Versionen nach sessionInfo.txt. Begleitet versions.txt und
# dokumentiert die tatsächlich geladene Umgebung.
# -------------------------------------------------------------
invisible(lapply(packages, function(p) {
  suppressPackageStartupMessages(requireNamespace(p, quietly = TRUE))
}))

session_file <- "sessionInfo.txt"
con <- file(session_file, "w")
writeLines(c(
  "# sessionInfo Snapshot",
  sprintf("# Generiert: %s", format(Sys.time(), "%Y-%m-%d %H:%M:%S %Z")),
  ""
), con)
capture.output(sessionInfo(), file = con)
close(con)
cat(sprintf("\n✓ Reproduzierbarkeits-Snapshot geschrieben: %s\n", session_file))
