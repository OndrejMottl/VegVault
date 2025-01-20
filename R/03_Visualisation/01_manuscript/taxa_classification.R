#----------------------------------------------------------#
#
#
#                       VegVault
#
#                      MNS figures
#                         Taxa
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#


#----------------------------------------------------------#
# 0. Load configuration -----
#----------------------------------------------------------#

library(here)

source(
  here::here(
    "R/00_Config_file.R"
  )
)

source(
  here::here(
    "R/03_Visualisation/01_manuscript/00_Config_mns.R"
  )
)

# helper function to get number of taxa per level
get_n_taxa_per_level <- function(sel_level) {
  dplyr::tbl(con, "TaxonClassification") %>%
    dplyr::distinct({{ sel_level }}) %>%
    dplyr::collect() %>%
    nrow() %>%
    return()
}

#----------------------------------------------------------#
# 1. Get data -----
#----------------------------------------------------------#

n_taxa_total <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::count(name = "N") %>%
  dplyr::collect() %>%
  purrr::chuck("N")

n_taxa_not_classificed <-
  dplyr::left_join(
    dplyr::tbl(con, "Taxa"),
    dplyr::tbl(con, "TaxonClassification"),
    by = "taxon_id"
  ) %>%
  dplyr::filter(
    is.na(taxon_species) &
      is.na(taxon_genus) &
      is.na(taxon_family)
  ) %>%
  dplyr::count(name = "N") %>%
  dplyr::collect() %>%
  purrr::chuck("N")

n_taxa_per_class <-
  tibble::tribble(
    ~class, ~N,
    "total taxa", n_taxa_total,
    "species", get_n_taxa_per_level(taxon_species),
    "genus", get_n_taxa_per_level(taxon_genus),
    "family", get_n_taxa_per_level(taxon_family),
    "not classified", n_taxa_not_classificed
  ) %>%
  dplyr::mutate(
    class = factor(
      class,
      levels = n_taxa_per_class$class
    )
  )


#----------------------------------------------------------#
# 2. Plot -----
#----------------------------------------------------------#

fig_n_taxa_per_class <-
  n_taxa_per_class %>%
  ggplot2::ggplot(
    ggplot2::aes(
      y = N,
      x = class
    )
  ) +
  ggplot2::labs(
    x = "",
    y = "Number of Taxa"
  ) +
  ggplot2::guides(
    fill = "none"
  ) +
  ggplot2::coord_cartesian(
    ylim = c(0, 120e3)
  ) +
  ggplot2::theme(
    panel.grid.major.x = ggplot2::element_blank()
  ) +
  ggplot2::geom_segment(
    mapping = ggplot2::aes(
      x = class,
      xend = class,
      yend = 0
    ),
    color = col_black, # [config]
    position = ggplot2::position_dodge(0.5)
  ) +
  ggplot2::geom_point(
    size = point_size,
    col = col_black, # [config]
    position = ggplot2::position_dodge(0.5)
  ) +
  ggplot2::geom_label(
    mapping = ggplot2::aes(
      label = scales::number(N)
    ),
    vjust = -0.5,
    size = point_size * 2,
    position = ggplot2::position_dodge(0.5)
  )

save_mns_figure(
  sel_plot = fig_n_taxa_per_class,
  image_width = list_img_width$double, # [config]
  image_height = 120
)
