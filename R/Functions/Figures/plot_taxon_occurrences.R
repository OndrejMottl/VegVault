#' @title Map the occurrences of one genus by age bin
#' @description
#' Draw the places where a genus occurs, one panel per age bin and
#' coloured by dataset type, as in the first v1 `vaultkeepr` example.
#' @param data_taxon_occurrences
#' A data frame as returned by `prepare_taxon_occurrences()`, with the
#' columns `dataset_type`, `coord_long`, `coord_lat` and `age_bin_class`.
#' @param list_region
#' Named list with the numeric scalars `lon_min`, `lon_max`, `lat_min` and
#' `lat_max` (degrees): the map extent.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @return
#' A ggplot object.
#' @details
#' Country outlines come from the `maps` package. Aborts when a required
#' column is missing.
#' @examples
#' \dontrun{
#' fig_na_picea <-
#'   plot_taxon_occurrences(
#'     data_taxon_occurrences = data_taxon_occurrences,
#'     list_region = list_region,
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_taxon_occurrences <- function(
  data_taxon_occurrences,
  list_region,
  list_figure_style
) {
  validate_data_columns(
    data_source = data_taxon_occurrences,
    vec_columns_required = c(
      "dataset_type", "coord_long", "coord_lat", "age_bin_class"
    ),
    name_argument = "data_taxon_occurrences"
  )

  validate_bounding_box(list_bounding_box = list_region)

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  point_size <-
    purrr::chuck(list_figure_style, "point_size")

  col_black <-
    purrr::chuck(list_figure_style, "colors", "black")

  res <-
    data_taxon_occurrences |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = coord_long,
        y = coord_lat
      )
    ) +
    ggplot2::facet_wrap(facets = ggplot2::vars(age_bin_class)) +
    ggplot2::scale_colour_manual(
      values = purrr::chuck(list_figure_style, "palettes", "dataset_type")
    ) +
    ggplot2::labs(
      x = "Longitude",
      y = "Latitude",
      colour = "Dataset type"
    ) +
    purrr::chuck(list_figure_style, "theme") +
    ggplot2::theme(legend.position = "top") +
    ggplot2::guides(
      colour = ggplot2::guide_legend(
        override.aes = list(size = point_size)
      )
    ) +
    ggplot2::coord_quickmap(
      xlim = c(
        purrr::chuck(list_region, "lon_min"),
        purrr::chuck(list_region, "lon_max")
      ),
      ylim = c(
        purrr::chuck(list_region, "lat_min"),
        purrr::chuck(list_region, "lat_max")
      )
    ) +
    build_world_borders_layer(
      col_fill = purrr::chuck(list_figure_style, "colors", "grey"),
      col_line = col_black,
      linewidth = purrr::chuck(list_figure_style, "line_size") / 2
    ) +
    ggplot2::geom_point(
      mapping = ggplot2::aes(colour = dataset_type),
      size = point_size
    ) +
    ggplot2::geom_point(
      colour = col_black,
      size = point_size / 10
    )

  return(res)
}
