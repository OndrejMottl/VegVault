#' @title Plot where and when the samples of datasets are
#' @description
#' Combine a world map of the dataset locations with a histogram of the
#' sample ages, coloured by dataset type and sharing one legend, as in the
#' v1 vegetation figure.
#' @param data_dataset_sample_ages
#' A data frame as returned by `load_dataset_sample_ages()`, with the
#' columns `dataset_id`, `dataset_type`, `coord_long`, `coord_lat` and
#' `age`.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @return
#' A ggplot object made by `cowplot::plot_grid()`: the legend on top, the
#' map and the histogram below.
#' @details
#' Dataset types are shown with spaces instead of underscores. The map
#' shows the distinct locations per type; the histogram counts the distinct
#' ages per dataset on a log scale, over 0 to 20 ka as in v1. Country
#' outlines come from the `maps` package. Aborts when a required column is
#' missing.
#' @examples
#' \dontrun{
#' fig_vegetation <-
#'   plot_sample_coverage(
#'     data_dataset_sample_ages = data_dataset_sample_ages,
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_sample_coverage <- function(
  data_dataset_sample_ages,
  list_figure_style
) {
  validate_data_columns(
    data_source = data_dataset_sample_ages,
    vec_columns_required = c(
      "dataset_id", "dataset_type", "coord_long", "coord_lat", "age"
    ),
    name_argument = "data_dataset_sample_ages"
  )

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  theme_figure <-
    purrr::chuck(list_figure_style, "theme")

  palette_dataset_type <-
    purrr::chuck(list_figure_style, "palettes", "dataset_type")

  data_labelled <-
    data_dataset_sample_ages |>
    dplyr::mutate(
      dataset_type = stringr::str_replace_all(dataset_type, "_", " ")
    )

  data_space <-
    data_labelled |>
    dplyr::distinct(dataset_type, coord_long, coord_lat)

  data_time <-
    data_labelled |>
    dplyr::distinct(dataset_id, dataset_type, age)

  fig_space <-
    ggplot2::ggplot() +
    ggplot2::scale_x_continuous(breaks = base::seq(-180, 180, by = 60)) +
    ggplot2::scale_y_continuous(breaks = base::seq(-90, 90, by = 30)) +
    ggplot2::scale_colour_manual(values = palette_dataset_type) +
    ggplot2::labs(
      x = "Longitude",
      y = "Latitude"
    ) +
    theme_figure +
    ggplot2::theme(legend.position = "none") +
    ggplot2::coord_sf() +
    build_world_borders_layer(
      col_fill = purrr::chuck(list_figure_style, "colors", "grey"),
      col_line = NA,
      linewidth = purrr::chuck(list_figure_style, "line_size")
    ) +
    ggplot2::geom_point(
      data = data_space,
      mapping = ggplot2::aes(
        x = coord_long,
        y = coord_lat,
        colour = dataset_type
      ),
      size = purrr::chuck(list_figure_style, "point_size") / 10,
      alpha = 0.5
    )

  vec_breaks_count <-
    10^(0:9)

  fig_time <-
    data_time |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = age,
        y = ggplot2::after_stat(count)
      )
    ) +
    ggplot2::scale_fill_manual(values = palette_dataset_type) +
    ggplot2::scale_y_continuous(
      transform = scales::transform_log1p(),
      breaks = vec_breaks_count,
      labels = c("1", "10", "100", stringr::str_c("1e", 3:9))
    ) +
    ggplot2::scale_x_continuous(
      breaks = base::seq(0, 20e3, by = 5e3),
      labels = base::seq(0, 20, by = 5)
    ) +
    ggplot2::labs(
      x = "Age (ka cal yr BP)",
      y = "Number of Samples",
      fill = "Dataset Type"
    ) +
    theme_figure +
    ggplot2::theme(legend.position = "top") +
    ggplot2::coord_cartesian(
      xlim = c(0.2, 20e3),
      ylim = c(1, 1e9)
    ) +
    ggplot2::geom_histogram(
      mapping = ggplot2::aes(fill = dataset_type),
      alpha = 1,
      bins = 20
    )

  grob_legend <-
    cowplot::get_plot_component(
      plot = fig_time,
      pattern = "guide-box-top"
    )

  fig_space_time <-
    cowplot::plot_grid(
      plotlist = list(
        fig_space,
        fig_time + ggplot2::theme(legend.position = "none")
      ),
      nrow = 1,
      rel_widths = c(1.5, 1)
    )

  res <-
    cowplot::plot_grid(
      plotlist = list(grob_legend, fig_space_time),
      nrow = 2,
      rel_heights = c(0.1, 1)
    )

  return(res)
}
