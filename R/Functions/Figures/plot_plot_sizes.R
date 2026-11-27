#' @title Plot the distribution of vegetation plot sizes
#' @description
#' Draw a histogram of the plot sizes, with both axes on log scales, as in
#' the v1 plot-size figure.
#' @param data_plot_sizes
#' A data frame as returned by `load_plot_sizes()`, with the columns
#' `sample_size` and `sample_size_unit`.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @return
#' A ggplot object; the x axis title names the size unit.
#' @details
#' Samples without a size are left out. Both axes are labelled as powers of
#' ten. The right margin is wider than in the other figures, so that the
#' label at the right end of the x axis stays inside the figure. Aborts
#' when a required column is missing, when no sample has a size, or when
#' the sizes have more than one unit.
#' @examples
#' \dontrun{
#' fig_samples_plot_size <-
#'   plot_plot_sizes(
#'     data_plot_sizes = data_plot_sizes,
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_plot_sizes <- function(
  data_plot_sizes,
  list_figure_style
) {
  validate_data_columns(
    data_source = data_plot_sizes,
    vec_columns_required = c("sample_size", "sample_size_unit"),
    name_argument = "data_plot_sizes"
  )

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  data_sized <-
    data_plot_sizes |>
    dplyr::filter(!base::is.na(sample_size))

  if (
    base::nrow(data_sized) == 0L
  ) {
    cli::cli_abort(
      "No sample has a plot size."
    )
  }

  vec_units <-
    data_sized |>
    dplyr::pull(sample_size_unit) |>
    base::unique() |>
    purrr::discard(.p = base::is.na)

  if (
    base::length(vec_units) > 1L
  ) {
    cli::cli_abort(
      "Plot sizes come in more than one unit: {.val {vec_units}}."
    )
  }

  label_size <-
    if (
      base::length(vec_units) == 1L
    ) {
      stringr::str_c("Plot size (", vec_units, ")")
    } else {
      "Plot size"
    }

  res <-
    data_sized |>
    ggplot2::ggplot(
      # An empty bin has no height on a log axis; as missing it is left out
      #   (na.rm below) instead of becoming an infinite value
      mapping = ggplot2::aes(
        x = sample_size,
        y = ggplot2::after_stat(dplyr::na_if(count, 0))
      )
    ) +
    ggplot2::scale_x_continuous(
      transform = "log10",
      breaks = scales::trans_breaks(
        trans = "log10",
        inv = function(x) 10^x
      ),
      labels = scales::trans_format(
        trans = "log10",
        format = scales::math_format(10^.x)
      )
    ) +
    ggplot2::scale_y_continuous(
      transform = "log10",
      breaks = scales::trans_breaks(
        trans = "log10",
        inv = function(x) 10^x
      ),
      labels = scales::trans_format(
        trans = "log10",
        format = scales::math_format(10^.x)
      )
    ) +
    ggplot2::labs(
      x = label_size,
      y = "Number of Samples"
    ) +
    purrr::chuck(list_figure_style, "theme") +
    ggplot2::theme(
      plot.margin = ggplot2::margin(
        t = 0.1,
        r = 0.5,
        b = 0,
        l = 0.1,
        unit = "cm"
      )
    ) +
    ggplot2::geom_histogram(
      fill = purrr::chuck(list_figure_style, "colors", "grey"),
      colour = NA,
      bins = 15,
      na.rm = TRUE
    )

  return(res)
}
