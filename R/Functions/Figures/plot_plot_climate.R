#' @title Map vegetation plots coloured by the climate of their gridpoint
#' @description
#' Draw the vegetation plots of a region, coloured by the abiotic value of
#' their linked gridpoint, over a graticule, as in the second v1
#' `vaultkeepr` example.
#' @param data_plot_climate
#' A data frame as returned by `prepare_plot_climate()`, with the columns
#' `coord_long`, `coord_lat`, `abiotic_variable_unit` and
#' `abiotic_value`.
#' @param list_region
#' Named list with the numeric scalars `lon_min`, `lon_max`, `lat_min` and
#' `lat_max` (degrees): the map extent.
#' @param abiotic_variable_label
#' Character scalar. The legend title of the variable, for example
#' `"MAT"`; its unit is added from the data.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @return
#' A ggplot object.
#' @details
#' The legend title is the label followed by the unit in parentheses. A
#' unit stored as a symbol with its name in parentheses, such as
#' `"C (degree Celsius)"`, is shown by its name only (`"MAT (degree
#' Celsius)"`), so that the parentheses are not nested. The graticule has
#' lines every 2 degrees of longitude and 0.5 degrees of latitude over the
#' region, as in v1. Country outlines come from the `maps` package. Aborts
#' when a required column is missing or the data hold more than one unit.
#' @examples
#' \dontrun{
#' fig_cz_jsdm <-
#'   plot_plot_climate(
#'     data_plot_climate = data_plot_climate,
#'     list_region = list_region,
#'     abiotic_variable_label = "MAT",
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_plot_climate <- function(
  data_plot_climate,
  list_region,
  abiotic_variable_label,
  list_figure_style
) {
  validate_data_columns(
    data_source = data_plot_climate,
    vec_columns_required = c(
      "coord_long", "coord_lat", "abiotic_variable_unit", "abiotic_value"
    ),
    name_argument = "data_plot_climate"
  )

  validate_bounding_box(list_bounding_box = list_region)

  assertthat::assert_that(
    base::is.character(abiotic_variable_label),
    base::length(abiotic_variable_label) == 1L,
    !base::is.na(abiotic_variable_label),
    msg = "`abiotic_variable_label` must be a character scalar."
  )

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  vec_units <-
    data_plot_climate |>
    dplyr::pull(abiotic_variable_unit) |>
    base::unique() |>
    purrr::discard(.p = base::is.na)

  if (
    base::length(vec_units) > 1L
  ) {
    cli::cli_abort(
      "The abiotic values come in more than one unit: {.val {vec_units}}."
    )
  }

  # A unit stored as "symbol (name)" is shown by its name, so that the
  #   parentheses of the title are not nested
  vec_units_shown <-
    stringr::str_replace(
      string = vec_units,
      pattern = "^.+ \\((.+)\\)$",
      replacement = "\\1"
    )

  label_colour <-
    if (
      base::length(vec_units_shown) == 1L
    ) {
      stringr::str_c(abiotic_variable_label, " (", vec_units_shown, ")")
    } else {
      abiotic_variable_label
    }

  lon_min <-
    purrr::chuck(list_region, "lon_min")

  lon_max <-
    purrr::chuck(list_region, "lon_max")

  lat_min <-
    purrr::chuck(list_region, "lat_min")

  lat_max <-
    purrr::chuck(list_region, "lat_max")

  point_size <-
    purrr::chuck(list_figure_style, "point_size")

  line_size <-
    purrr::chuck(list_figure_style, "line_size")

  col_black <-
    purrr::chuck(list_figure_style, "colors", "black")

  col_white <-
    purrr::chuck(list_figure_style, "colors", "white")

  res <-
    data_plot_climate |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = coord_long,
        y = coord_lat
      )
    ) +
    ggplot2::scale_colour_steps(
      low = purrr::chuck(list_figure_style, "colors", "brown_neutral"),
      high = purrr::chuck(list_figure_style, "colors", "red")
    ) +
    ggplot2::labs(
      x = "Longitude",
      y = "Latitude",
      colour = label_colour
    ) +
    purrr::chuck(list_figure_style, "theme") +
    ggplot2::theme(legend.position = "top") +
    ggplot2::coord_quickmap(
      xlim = c(lon_min, lon_max),
      ylim = c(lat_min, lat_max)
    ) +
    build_world_borders_layer(
      col_fill = purrr::chuck(list_figure_style, "colors", "grey"),
      col_line = NA,
      linewidth = line_size
    ) +
    ggplot2::geom_vline(
      xintercept = base::seq(from = lon_min, to = lon_max, by = 2),
      linewidth = line_size,
      colour = col_white
    ) +
    ggplot2::geom_hline(
      yintercept = base::seq(from = lat_min, to = lat_max, by = 0.5),
      linewidth = line_size,
      colour = col_white
    ) +
    build_world_borders_layer(
      col_fill = NA,
      col_line = col_black,
      linewidth = line_size / 2
    ) +
    ggplot2::geom_point(
      mapping = ggplot2::aes(colour = abiotic_value),
      size = point_size
    ) +
    ggplot2::geom_point(
      colour = col_black,
      size = point_size / 10
    )

  return(res)
}
