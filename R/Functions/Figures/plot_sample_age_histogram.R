#' @title Plot the number of samples per age bin and dataset type
#' @description
#' Draw the samples of each dataset type per age bin as bars on a log
#' scale. The bars of one bin are overlaid, not stacked, so that the top of
#' each bar reads its own count on the axis.
#' @param data_sample_ages
#' A data frame with one row per sample and the columns `dataset_type`
#' (character, the label shown in the legend) and `age` (numeric, years
#' cal BP).
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`; its palette
#' `dataset_type` must name every dataset type of the data.
#' @param bin_width
#' Positive numeric scalar. Width of the age bins in years (default 1000).
#' @param age_max
#' Positive numeric scalar. Oldest age shown, in years (default 20000).
#' @return
#' A ggplot object with the legend on top and one `geom_col()` layer per
#' drawing rank: the largest count of each bin in the first layer, the
#' smaller ones in front of it.
#' @details
#' Bins start at age 0; ages after 1950 (negative) count in the first bin.
#' Samples without an age are left out. Every bar starts at zero. ggplot2
#' stacks bars after transforming the axis, so bars stacked on a log scale
#' would show the product of the counts instead of their sum; overlaying
#' keeps every count true. The y axis title names the bin width. Aborts
#' when a required column is missing, when an argument is invalid, or when
#' no sample has an age.
#' @examples
#' \dontrun{
#' fig_time <-
#'   plot_sample_age_histogram(
#'     data_sample_ages = data_time,
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_sample_age_histogram <- function(
  data_sample_ages,
  list_figure_style,
  bin_width = 1000,
  age_max = 20000
) {
  validate_data_columns(
    data_source = data_sample_ages,
    vec_columns_required = c("dataset_type", "age"),
    name_argument = "data_sample_ages"
  )

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  assertthat::assert_that(
    base::is.numeric(bin_width),
    base::length(bin_width) == 1L,
    !base::is.na(bin_width),
    bin_width > 0,
    msg = "`bin_width` must be a positive number."
  )

  assertthat::assert_that(
    base::is.numeric(age_max),
    base::length(age_max) == 1L,
    !base::is.na(age_max),
    age_max > 0,
    msg = "`age_max` must be a positive number."
  )

  data_aged <-
    data_sample_ages |>
    dplyr::filter(!base::is.na(age))

  if (
    base::nrow(data_aged) == 0L
  ) {
    cli::cli_abort(
      "No sample has an age."
    )
  }

  # Samples per bin and type; ages after 1950 count in the first bin. The
  #   rank orders the bars of a bin from the largest count down
  data_bins <-
    data_aged |>
    dplyr::mutate(
      age_bin = (base::floor(base::pmax(age, 0) / bin_width) + 0.5) *
        bin_width
    ) |>
    dplyr::count(age_bin, dataset_type, name = "n_samples") |>
    dplyr::group_by(age_bin) |>
    dplyr::mutate(
      rank_draw = base::rank(-n_samples, ties.method = "first")
    ) |>
    dplyr::ungroup()

  vec_ranks_draw <-
    data_bins |>
    dplyr::pull(rank_draw) |>
    base::unique() |>
    base::sort()

  # One layer per rank: the largest bar of each bin first, the smaller ones
  #   in front of it, all from zero (stacked bars on a log scale would
  #   multiply the counts)
  list_layers_bars <-
    purrr::map(
      .x = vec_ranks_draw,
      .f = ~ ggplot2::geom_col(
        data = dplyr::filter(data_bins, rank_draw == .x),
        mapping = ggplot2::aes(
          x = age_bin,
          y = n_samples,
          fill = dataset_type
        ),
        width = bin_width
      )
    )

  label_count <-
    stringr::str_c(
      "Samples per ",
      scales::label_comma()(bin_width),
      " years"
    )

  res <-
    ggplot2::ggplot() +
    ggplot2::scale_fill_manual(
      values = purrr::chuck(list_figure_style, "palettes", "dataset_type")
    ) +
    ggplot2::scale_y_continuous(
      transform = scales::transform_log1p(),
      breaks = 10^(0:9),
      labels = scales::label_comma()
    ) +
    ggplot2::scale_x_continuous(
      breaks = base::seq(0, age_max, by = 5e3),
      labels = base::seq(0, age_max, by = 5e3) / 1e3
    ) +
    ggplot2::labs(
      x = "Age (ka cal yr BP)",
      y = label_count,
      fill = "Dataset Type"
    ) +
    purrr::chuck(list_figure_style, "theme") +
    ggplot2::theme(legend.position = "top") +
    ggplot2::coord_cartesian(
      xlim = c(0, age_max)
    ) +
    list_layers_bars

  return(res)
}
