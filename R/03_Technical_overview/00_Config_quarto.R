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
    paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
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
  fig.path = "figures/",
  out.width = "100%"
)

# theme setup
ggplot2::theme_set(
  ggplot2::theme_bw() +
    ggplot2::theme(
      text = ggplot2::element_text(size = text_size), # [config]
      line = ggplot2::element_line(size = line_size), # [config]
      plot.title = ggplot2::element_text(size = 15),
      axis.title = ggplot2::element_text(size = 15),
      axis.text = ggplot2::element_text(size = 15),
      strip.text = ggplot2::element_text(size = 15),
      panel.grid = ggplot2::element_blank()
    )
)

# N characters for wrapping text
fig_width_def <- 60 # this is used to wrap text.

# 3.1 palette setup -----
palette_dataset_type <-
  c(
    "#3DDC97",
    "#AA6DA3",
    "#156064",
    "#5F634F"
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
    "#3DDC97",
    "#3DDC47",
    "#AA6DA3",
    "#156064",
    "#5F634F"
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
  c(
    "#156064",
    "#1C6C84",
    "#47749F",
    "#7C78AD",
    "#AE7AAC",
    "#D57F9C"
  ) %>%
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

# 3.2 helper functions -----

#' @description
#' A helper function to colour the facets
color_facets <-
  function(sel_plot,
           sel_palette,
           direction = c("vertical", "horizontal"),
           return_raw = FALSE) {
    direction <- match.arg(direction)
    g <-
      ggplot2::ggplot_gtable(
        ggplot2::ggplot_build(sel_plot)
      )
    stripr <-
      which(grepl("strip-t", g$layout$name))

    for (i in seq_along(stripr)) {
      object_val <-
        sort(stripr,
          decreasing = ifelse(direction == "vertical",
            TRUE,
            FALSE
          )
        )[i]

      j <-
        which(grepl("rect", g$grobs[[object_val]]$grobs[[1]]$childrenOrder))

      g$grobs[[object_val]]$grobs[[1]]$children[[j]]$gp$fill <-
        sel_palette[i]
    }

    if (
      return_raw == TRUE
    ) {
      return(g)
    } else {
      grid::grid.draw(g)
    }
  }