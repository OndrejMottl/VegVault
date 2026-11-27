#' @title Plot an empty map with one country outlined
#' @description
#' Draw the land of a map extent with one country outlined in red, the
#' base of the maps of the gridpoint figure.
#' @param data_country_border
#' An `sf` object with the outline of the country (see
#' `load_country_border()`).
#' @param list_extent
#' Named list with the numeric scalars `lon_min`, `lon_max`, `lat_min` and
#' `lat_max` (degrees): the map extent.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @param n_breaks_lon
#' `NULL` (default) or a positive whole number: the approximate number of
#' longitude labels, for a map too narrow for the labels that `coord_sf()`
#' chooses. `NULL` keeps the `coord_sf()` labels.
#' @return
#' A ggplot object with `coord_sf()` on the extent, the land of the `maps`
#' package in grey and the country outline; layers can be added to it.
#' @details
#' With `n_breaks_lon`, the longitudes are chosen by
#' `scales::breaks_extended()`, which may return one label more or fewer.
#' @examples
#' \dontrun{
#' fig_overview <-
#'   plot_country_map(
#'     data_country_border = data_country_border,
#'     list_extent = list(
#'       lon_min = -10, lon_max = 32, lat_min = 35, lat_max = 60
#'     ),
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_country_map <- function(
  data_country_border,
  list_extent,
  list_figure_style,
  n_breaks_lon = NULL
) {
  assertthat::assert_that(
    base::inherits(data_country_border, "sf"),
    msg = "`data_country_border` must be an sf object."
  )

  validate_bounding_box(list_bounding_box = list_extent)

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  assertthat::assert_that(
    base::is.null(n_breaks_lon) ||
      (
        base::is.numeric(n_breaks_lon) &&
          base::length(n_breaks_lon) == 1L &&
          !base::is.na(n_breaks_lon) &&
          n_breaks_lon >= 1 &&
          n_breaks_lon == base::round(n_breaks_lon)
      ),
    msg = "`n_breaks_lon` must be NULL or a positive whole number."
  )

  # NULL keeps the longitudes that coord_sf() chooses
  scale_lon <-
    NULL

  if (
    !base::is.null(n_breaks_lon)
  ) {
    scale_lon <-
      ggplot2::scale_x_continuous(
        breaks = scales::breaks_extended(n = n_breaks_lon)
      )
  }

  res <-
    ggplot2::ggplot() +
    scale_lon +
    ggplot2::labs(
      x = "Longitude",
      y = "Latitude"
    ) +
    purrr::chuck(list_figure_style, "theme") +
    build_world_borders_layer(
      col_fill = purrr::chuck(list_figure_style, "colors", "grey"),
      col_line = NA,
      linewidth = purrr::chuck(list_figure_style, "line_size")
    ) +
    ggplot2::geom_sf(
      data = data_country_border,
      fill = NA,
      colour = purrr::chuck(list_figure_style, "colors", "red")
    ) +
    # After geom_sf(), which brings its own default coord_sf() that would
    #   replace an earlier one and drop the extent
    ggplot2::coord_sf(
      xlim = c(
        purrr::chuck(list_extent, "lon_min"),
        purrr::chuck(list_extent, "lon_max")
      ),
      ylim = c(
        purrr::chuck(list_extent, "lat_min"),
        purrr::chuck(list_extent, "lat_max")
      )
    )

  return(res)
}
