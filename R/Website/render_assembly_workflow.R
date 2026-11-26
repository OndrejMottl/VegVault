#----------------------------------------------------------#
#
#
#                       VegVault
#
#           Figure of the data assembly (website)
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#
# Draws the figure of the data assembly of the website from the nodes and
#   links of `website: assembly_workflow` in config.yml, with the logos of
#   Data/Website/Logos, in the colours of colors.json. The figure is
#   replaced. Run from the repository root:
#
#   Rscript R/Website/render_assembly_workflow.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

list_settings <-
  load_config_value(value = c("website", "assembly_workflow"))

# colors.json may carry an alpha value; the figure takes #RRGGBB
list_colors <-
  load_figure_colors(path_colors = here::here("colors.json")) |>
  purrr::map(.f = ~ stringr::str_sub(.x, start = 1L, end = 7L))


#----------------------------------------------------------#
# 1. Nodes and links -----
#----------------------------------------------------------#

# Fields a node does not set are missing; a node has a box unless it says
#   otherwise, and logo paths are relative to the project root
data_nodes <-
  list_settings |>
  purrr::chuck("nodes") |>
  purrr::map(.f = tibble::as_tibble) |>
  dplyr::bind_rows() |>
  dplyr::bind_rows(
    tibble::tibble(
      box = base::logical(0),
      logo = base::character(0),
      logo_size = base::double(0),
      label = base::character(0),
      icon = base::character(0)
    )
  ) |>
  dplyr::mutate(
    id = base::as.integer(id),
    box = dplyr::coalesce(box, TRUE),
    logo = dplyr::if_else(base::is.na(logo), NA_character_, here::here(logo))
  )

data_edges <-
  list_settings |>
  purrr::chuck("edges") |>
  purrr::map(
    .f = ~ tibble::tibble(
      from = base::as.integer(.x[[1]]),
      to = base::as.integer(.x[[2]])
    )
  ) |>
  dplyr::bind_rows()


#----------------------------------------------------------#
# 2. Draw and save -----
#----------------------------------------------------------#

plot_workflow <-
  plot_assembly_workflow(
    data_nodes = data_nodes,
    data_edges = data_edges,
    list_colors = list_colors,
    color_background = purrr::chuck(list_settings, "background"),
    color_link = purrr::chuck(list_settings, "link")
  )

ggplot2::ggsave(
  filename = here::here(purrr::chuck(list_settings, "file")),
  plot = plot_workflow,
  width = purrr::chuck(list_settings, "width_mm"),
  height = purrr::chuck(list_settings, "height_mm"),
  units = "mm",
  dpi = purrr::chuck(list_settings, "dpi"),
  bg = purrr::chuck(list_colors, purrr::chuck(list_settings, "background"))
)
