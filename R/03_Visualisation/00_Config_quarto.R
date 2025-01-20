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

# define general
text_size <- 32
line_size <- 0.1
point_size <- 3

# define font
sysfonts::font_add(
  family = "Renogare",
  regular = here::here("Fonts/Renogare-Regular.otf")
)
showtext::showtext_auto()

# define output sizes
image_width <- 2450
image_height <- 1200
image_units <- "px"

# define common color
col_brown_light <- "#BC7052"
col_brown_dark <- "#8A554E"

col_green_light <- "#9BC058"
col_green_dark <- "#5D7841"

col_blue_light <- "#52758F"
col_blue_dark <- "#242531"

col_beige_light <- "#E6B482"
col_beige_dark <- "#AE8a7B"

col_white <- "white"


# set ggplot output
ggplot2::theme_set(
  ggplot2::theme_minimal() +
    ggplot2::theme(
      text = ggplot2::element_text(
        size = text_size,
        colour = col_blue_dark,
        family = "Renogare"
      ),
      line = ggplot2::element_line(
        linewidth = line_size,
        colour = col_blue_dark
      ),
      axis.text = ggplot2::element_text(
        colour = col_blue_dark,
        size = text_size,
        family = "Renogare"
      ),
      axis.title = ggplot2::element_text(
        colour = col_blue_dark,
        size = text_size,
        family = "Renogare"
      ),
      panel.grid.major = ggplot2::element_line(
        colour = col_white,
        linewidth = line_size
      ),
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(
        fill = col_beige_light,
        colour = col_beige_light
      ),
      panel.background = ggplot2::element_rect(
        fill = col_brown_light,
        colour = col_brown_light
      ),
    )
)

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
