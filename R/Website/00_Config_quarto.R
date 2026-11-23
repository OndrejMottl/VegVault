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

# Load dynamic colors and fonts from JSON
colors_data <-
  jsonlite::fromJSON(here::here("colors.json"))

colors_data_short <-
  colors_data %>%
  purrr::map(
    .f = ~ stringr::str_remove(., "#") %>%
      stringr::str_sub(1, 6)
  )

fonts_data <-
  jsonlite::fromJSON(here::here("fonts.json"))

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

# define font - using dynamic font system
font_family <-
  fonts_data$body


if (
  !font_family %in% sysfonts::font_families()
) {
  sysfonts::font_add_google(
    name = font_family
  )
}

showtext::showtext_auto()

# define output sizes
image_width <- 2450
image_height <- 1200
image_units <- "px"

# define colors using dynamic color system
col_brown_light <- colors_data$brownLight
col_brown_dark <- colors_data$brownDark

col_green_light <- colors_data$greenLight
col_green_dark <- colors_data$greenDark

col_blue_light <- colors_data$blueLight
col_blue_dark <- colors_data$blueDark

col_beige_light <- colors_data$beigeLight
col_beige_dark <- colors_data$beigeDark

col_white <- colors_data$white
col_black <- colors_data$black

# Additional colors for expanded palette
col_purple_light <- colors_data$purpleLight
col_purple_dark <- colors_data$purpleDark


# set ggplot output
ggplot2::theme_set(
  ggplot2::theme_minimal() +
    ggplot2::theme(
      text = ggplot2::element_text(
        size = text_size,
        colour = col_black,
        family = font_family
      ),
      line = ggplot2::element_line(
        linewidth = line_size,
        colour = col_black
      ),
      axis.text = ggplot2::element_text(
        colour = col_black,
        size = text_size,
        family = font_family
      ),
      axis.title = ggplot2::element_text(
        colour = col_black,
        size = text_size,
        family = font_family
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
      strip.background = ggplot2::element_rect(
        fill = col_brown_dark,
        colour = col_black
      ),
      strip.text = ggplot2::element_text(
        colour = col_white,
        size = text_size,
        family = font_family
      ),
      strip.text.x = ggplot2::element_text(
        colour = col_white,
        size = text_size,
        family = font_family
      ),
      strip.text.y = ggplot2::element_text(
        colour = col_white,
        size = text_size,
        family = font_family
      )
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
    col_green_light,
    col_purple_light,
    col_blue_dark,
    col_green_dark
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
    col_green_light,
    col_purple_light,
    col_blue_dark,
    col_green_dark
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
      col_blue_dark,
      col_brown_light
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
