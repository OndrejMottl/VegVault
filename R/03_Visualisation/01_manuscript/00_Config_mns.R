#----------------------------------------------------------#
#
#
#                       VegVault
#
#             Config file for MNS documents
#
#
#                       O. Mottl
#                         2025
#
#----------------------------------------------------------#
# Configuration script to make sure all scripts for the mns
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
# 1. Conect to Database -----
#----------------------------------------------------------#

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_to_vegvault
  )


#----------------------------------------------------------#
# 2. Graphical settings -----
#----------------------------------------------------------#

# define general
text_size <- 14
line_size <- 0.1
point_size <- 3

# N characters for wrapping text
fig_width_def <- 60 # this is used to wrap text.

# define output sizes
list_img_width <-
  list(
    "single" = 89,
    "double" = 183,
    "full" = 247
  )

image_units <- "mm"

## 2.1 define common color -----
col_green_light <- "#3DDC97"
col_green_dark <- "#3DDC47"
col_purple <- "#AA6DA3"
col_dark_blue <- "#156064"
col_brown_neutral <- "#5F634F"

col_brown_light <- "#BC7052"
col_brown_dark <- "#8A554E"

col_white <- "white"
col_grey <- "#999999"
col_black <- "#242531"

## 2.2 palette setup -----
palette_dataset_type <-
  c(
    col_green_dark,
    col_purple,
    col_dark_blue,
    col_brown_neutral
  ) %>%
  rlang::set_names(
    nm = c(
      "vegetation plot",
      "fossil pollen archive",
      "traits",
      "gridpoints"
    )
  )

palette_dataset_source_type <-
  c(
    col_green_light,
    col_green_dark,
    col_purple,
    col_dark_blue,
    col_brown_neutral
  ) %>%
  rlang::set_names(
    nm = c(
      "BIEN",
      "sPlotOpen",
      "Neotoma - FOSSILPOL",
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

## 2.3 set ggplot output -----
ggplot2::theme_set(
  ggplot2::theme_minimal() +
    ggplot2::theme(
      text = ggplot2::element_text(
        size = text_size,
        colour = col_black
      ),
      line = ggplot2::element_line(
        linewidth = line_size,
        colour = col_black
      ),
      axis.text = ggplot2::element_text(
        colour = col_black,
        size = text_size
      ),
      axis.title = ggplot2::element_text(
        colour = col_black,
        size = text_size
      ),
      panel.grid.major = ggplot2::element_line(
        colour = col_grey,
        linewidth = line_size
      ),
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(
        fill = col_white,
        colour = col_white
      ),
      panel.background = ggplot2::element_rect(
        fill = col_white,
        colour = col_grey
      ),
      plot.margin = ggplot2::margin(
        t = 0.1,
        r = 0.1,
        b = 0,
        l = 0,
        unit = "cm"
      )
    )
)
