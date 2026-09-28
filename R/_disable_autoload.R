# Tells shiny::runApp() NOT to auto-source every file in R/.
# app.R sources config.R, functions.R and load_data.R itself; without this file
# Shiny would also run helper/one-off scripts that happen to live in R/.
