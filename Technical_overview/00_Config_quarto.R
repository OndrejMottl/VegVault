#----------------------------------------------------------#
#
#
#                       VegVault
#
#             Config file for Quarto documents
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#
# Configuration script to make sure all seetting for QUARTO documents
#   are set up correctly and cosistently


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#
library(here)

# Load configuration
source(
  here::here(
    "R/00_Config_file.R"
  )
)


#----------------------------------------------------------#
# 1. Select example dataset -----
#----------------------------------------------------------#

sel_dataset_for_example <- 91256


#----------------------------------------------------------#
# 2. Conect to Database -----
#----------------------------------------------------------#

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_to_vegvault
  )


#----------------------------------------------------------#
# 3. Graphical settings -----
#----------------------------------------------------------#

# chunk setup
knitr::opts_chunk$set(
  collapse = TRUE,
  comment = "#>",
  echo = FALSE,
  message = FALSE,
  warning = FALSE,
  fig.align = "center",
  fig.path = "Figures/",
  out.width = "100%",
  fig.bg = col_beige_light,
  background = col_beige_light,
  strip.white = FALSE
)


# N characters for wrapping text
fig_width_def <- 60 # this is used to wrap text.

# 3.1 palette setup -----
palette_dataset_type <-
  c(
    col_green_dark,
    col_blue_light,
    col_brown_dark,
    col_white
  ) %>%
  rlang::set_names(
    nm = c(
      "vegetation_plot",
      "fossil_pollen_archive",
      "traits",
      "gridpoints"
    )
  )

palette_dataset_source_type <-
  c(
    col_green_dark,
    col_green_light,
    col_blue_light,
    col_brown_dark,
    col_white
  ) %>%
  rlang::set_names(
    nm = c(
      "BIEN",
      "sPlotOpen",
      "FOSSILPOL",
      "TRY",
      "gridpoints"
    )
  )

palette_trait_dommanins <-
  grDevices::colorRampPalette(
    c(
      col_brown_light,
      col_brown_dark
    )
  )(6) %>%
  rlang::set_names(
    nm = c(
      "Diaspore mass",
      "Leaf Area",
      "Leaf mass pr area",
      "Leaf nitrogen content per unit mass",
      "Plant heigh",
      "Stem specific density"
    )
  )
