#' @title Plot the number of datasets per type and source
#' @description
#' Combine a waffle chart of the datasets per type with a lollipop chart
#' of the datasets per source type, one panel per dataset type, as in the
#' v1 dataset figure.
#' @param data_dataset_counts
#' A data frame as returned by `load_dataset_counts()`, with the columns
#' `dataset_type`, `dataset_source_type` and `n_datasets`.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @return
#' A ggplot object made by `cowplot::plot_grid()`: the waffle chart left,
#' the lollipop chart (log scale) right.
#' @details
#' Labels and order come from `prepare_dataset_counts()`. The waffle counts
#' every dataset of a type; the lollipops show only datasets with a source
#' type, as in v1. Each panel strip takes the colour of its type, in the
#' order of the panels (v1 listed the colours by hand). One square stands
#' for `compute_waffle_unit()` datasets: 1000 for the v1 database, as in
#' v1. The log axis ends at `compute_log_axis_max()` (10 million for the v1
#' counts, as in v1), and the stems start at one dataset, its lower limit
#' (v1 drew them from zero, outside the log axis). Aborts when a required
#' column is missing.
#' @examples
#' \dontrun{
#' fig_datasets <-
#'   plot_dataset_counts(
#'     data_dataset_counts = data_dataset_counts,
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_dataset_counts <- function(
  data_dataset_counts,
  list_figure_style
) {
  validate_data_columns(
    data_source = data_dataset_counts,
    vec_columns_required = c(
      "dataset_type", "dataset_source_type", "n_datasets"
    ),
    name_argument = "data_dataset_counts"
  )

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  theme_figure <-
    purrr::chuck(list_figure_style, "theme")

  point_size <-
    purrr::chuck(list_figure_style, "point_size")

  col_black <-
    purrr::chuck(list_figure_style, "colors", "black")

  col_white <-
    purrr::chuck(list_figure_style, "colors", "white")

  palette_dataset_type <-
    purrr::chuck(list_figure_style, "palettes", "dataset_type")

  data_counts_labelled <-
    prepare_dataset_counts(data_dataset_counts = data_dataset_counts)

  # The waffle lists the types alphabetically, as in v1
  data_counts_per_type <-
    data_counts_labelled |>
    dplyr::mutate(dataset_type = base::as.character(dataset_type)) |>
    dplyr::group_by(dataset_type) |>
    dplyr::summarise(
      N = base::sum(n_datasets),
      .groups = "drop"
    )

  fig_waffle <-
    plot_waffle(
      data_source = data_counts_per_type,
      var_name = dataset_type,
      one_point_is = compute_waffle_unit(
        n_total = base::sum(dplyr::pull(data_counts_per_type, N))
      ),
      col_background = col_white,
      col_lines = col_black,
      legend_position = "top",
      legend_n_col = 2,
      data_point_name = "Datasets",
      theme_base = theme_figure
    ) +
    ggplot2::scale_fill_manual(values = palette_dataset_type)

  data_counts_sourced <-
    data_counts_labelled |>
    dplyr::filter(!base::is.na(dataset_source_type)) |>
    dplyr::mutate(dataset_type = base::droplevels(dataset_type))

  position_lollipop <-
    ggplot2::position_dodge(width = 0.5)

  fig_lollipop <-
    data_counts_sourced |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = dataset_source_type,
        y = n_datasets
      )
    ) +
    ggplot2::facet_wrap(
      facets = ggplot2::vars(dataset_type),
      nrow = 1,
      scales = "free_x"
    ) +
    ggplot2::scale_y_continuous(
      transform = scales::transform_log10(),
      breaks = scales::trans_breaks(
        trans = "log10",
        inv = function(x) 10^x
      ),
      labels = scales::trans_format(
        trans = "log10",
        format = scales::math_format(10^.x)
      ),
      limits = c(
        1,
        compute_log_axis_max(
          n_max = base::max(dplyr::pull(data_counts_sourced, n_datasets))
        )
      )
    ) +
    ggplot2::scale_fill_manual(
      values = purrr::chuck(
        list_figure_style,
        "palettes",
        "dataset_source_type"
      )
    ) +
    ggplot2::labs(
      x = "Data Source",
      y = "Number of Datasets"
    ) +
    theme_figure +
    ggplot2::theme(
      panel.grid.major.x = ggplot2::element_blank(),
      legend.position = "none",
      strip.background = ggplot2::element_rect(
        fill = col_white,
        colour = purrr::chuck(list_figure_style, "colors", "grey")
      ),
      strip.text = ggplot2::element_text(colour = col_black),
      axis.text.x = ggplot2::element_blank()
    ) +
    ggplot2::geom_segment(
      mapping = ggplot2::aes(
        xend = dataset_source_type,
        yend = 1
      ),
      colour = col_black,
      position = position_lollipop
    ) +
    ggplot2::geom_point(
      mapping = ggplot2::aes(fill = dataset_source_type),
      size = point_size,
      shape = 21,
      colour = col_black,
      position = position_lollipop
    ) +
    ggplot2::geom_label(
      mapping = ggplot2::aes(label = scales::number(n_datasets)),
      vjust = -0.5,
      size = point_size,
      position = position_lollipop
    ) +
    ggplot2::geom_text(
      mapping = ggplot2::aes(
        y = 2,
        label = dataset_source_type
      ),
      hjust = 0,
      vjust = 0,
      angle = 90,
      size = point_size,
      position = position_lollipop
    )

  # Each strip takes the colour of its type, in the order of the panels
  vec_strip_colours <-
    palette_dataset_type[
      base::levels(dplyr::pull(data_counts_sourced, dataset_type))
    ]

  grob_lollipop <-
    color_facets(
      sel_plot = fig_lollipop,
      sel_palette = vec_strip_colours,
      direction = "horizontal",
      return_raw = TRUE
    )

  res <-
    cowplot::plot_grid(
      plotlist = list(fig_waffle, grob_lollipop),
      ncol = 2,
      nrow = 1,
      rel_widths = c(1, 2)
    )

  return(res)
}
