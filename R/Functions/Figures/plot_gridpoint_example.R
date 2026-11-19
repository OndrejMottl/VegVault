#' @title Plot the gridpoints of a region and their links to plots
#' @description
#' Combine an overview map with the outlined country, a map of the
#' gridpoints in the region, and a map of the vegetation plots linked to
#' their gridpoints, as in the v1 gridpoint figure.
#' @param data_country_border
#' An `sf` object with the outline of the country (see
#' `load_country_border()`).
#' @param data_gridpoint_locations
#' A data frame as returned by `load_gridpoint_locations()`, with the
#' columns `coord_long` and `coord_lat`.
#' @param data_gridpoint_links
#' A data frame as returned by `prepare_gridpoint_links()`.
#' @param list_region,list_overview
#' Named lists with the numeric scalars `lon_min`, `lon_max`, `lat_min`
#' and `lat_max` (degrees): the extent of the region maps and of the
#' overview map.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @return
#' A ggplot object made by `cowplot::plot_grid()`: the overview and the
#' gridpoint map on the left, the link map on the right.
#' @details
#' Country outlines come from the `maps` package, the highlighted country
#' from `data_country_border`. Axis breaks are the `coord_sf()` defaults
#' for each extent (v1 listed them for Czechia and Europe). Aborts when a
#' required column is missing.
#' @examples
#' \dontrun{
#' fig_gridpoints_example <-
#'   plot_gridpoint_example(
#'     data_country_border = data_country_border,
#'     data_gridpoint_locations = data_gridpoint_locations,
#'     data_gridpoint_links = data_gridpoint_links,
#'     list_region = list_region,
#'     list_overview = list_overview,
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_gridpoint_example <- function(
  data_country_border,
  data_gridpoint_locations,
  data_gridpoint_links,
  list_region,
  list_overview,
  list_figure_style
) {
  assertthat::assert_that(
    base::inherits(data_country_border, "sf"),
    msg = "`data_country_border` must be an sf object."
  )

  validate_data_columns(
    data_source = data_gridpoint_locations,
    vec_columns_required = c("coord_long", "coord_lat"),
    name_argument = "data_gridpoint_locations"
  )

  validate_data_columns(
    data_source = data_gridpoint_links,
    vec_columns_required = c(
      "coord_long_plot", "coord_lat_plot", "coord_long_gridpoint",
      "coord_lat_gridpoint"
    ),
    name_argument = "data_gridpoint_links"
  )

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  point_size <-
    purrr::chuck(list_figure_style, "point_size")

  col_brown_neutral <-
    purrr::chuck(list_figure_style, "colors", "brown_neutral")

  fig_overview <-
    plot_country_map(
      data_country_border = data_country_border,
      list_extent = list_overview,
      list_figure_style = list_figure_style
    )

  fig_region <-
    plot_country_map(
      data_country_border = data_country_border,
      list_extent = list_region,
      list_figure_style = list_figure_style
    )

  fig_gridpoints <-
    fig_region +
    ggplot2::geom_point(
      data = data_gridpoint_locations,
      mapping = ggplot2::aes(
        x = coord_long,
        y = coord_lat
      ),
      shape = 15,
      size = point_size / 6,
      alpha = 1,
      colour = col_brown_neutral
    )

  data_links <-
    data_gridpoint_links |>
    dplyr::filter(!base::is.na(coord_long_gridpoint))

  data_gridpoints_linked <-
    data_links |>
    dplyr::distinct(coord_long_gridpoint, coord_lat_gridpoint)

  fig_links <-
    fig_region +
    ggplot2::geom_segment(
      data = data_links,
      mapping = ggplot2::aes(
        x = coord_long_gridpoint,
        y = coord_lat_gridpoint,
        xend = coord_long_plot,
        yend = coord_lat_plot
      ),
      colour = col_brown_neutral,
      linewidth = purrr::chuck(list_figure_style, "line_size")
    ) +
    ggplot2::geom_point(
      data = data_gridpoints_linked,
      mapping = ggplot2::aes(
        x = coord_long_gridpoint,
        y = coord_lat_gridpoint
      ),
      shape = 15,
      alpha = 1,
      size = point_size / 2,
      colour = col_brown_neutral
    ) +
    ggplot2::geom_point(
      data = data_gridpoint_links,
      mapping = ggplot2::aes(
        x = coord_long_plot,
        y = coord_lat_plot
      ),
      shape = 20,
      alpha = 0.5,
      size = point_size / 3,
      colour = purrr::chuck(list_figure_style, "colors", "green_dark")
    )

  fig_overview_gridpoints <-
    cowplot::plot_grid(
      plotlist = list(fig_overview, fig_gridpoints),
      ncol = 1,
      nrow = 2,
      rel_heights = c(1.4, 1)
    )

  res <-
    cowplot::plot_grid(
      plotlist = list(fig_overview_gridpoints, fig_links),
      ncol = 2,
      nrow = 1,
      rel_widths = c(1, 2.4)
    )

  return(res)
}
