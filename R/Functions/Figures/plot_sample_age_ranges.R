#' @title Plot the sample ages of a dataset with their iteration range
#' @description
#' Draw each sample at its age, with a segment over the range of its
#' age-model iterations, as in the v1 sample-age figure.
#' @param data_sample_age_ranges
#' A data frame as returned by `load_sample_age_ranges()`, with the
#' columns `dataset_name`, `sample_id`, `age`, `age_iteration_min` and
#' `age_iteration_max`.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @return
#' A ggplot object with fixed 1:1 axes in thousands of years, both
#' starting at zero, and the dataset name as caption.
#' @details
#' The upper axis limits are the next multiple of 5000 years above the
#' oldest iteration (x) and the oldest sample (y); v1 fixed them at 20 and
#' 12 ka for one dataset. Aborts when a required column is missing or the
#' data hold more than one dataset.
#' @examples
#' \dontrun{
#' fig_sample_age <-
#'   plot_sample_age_ranges(
#'     data_sample_age_ranges = data_sample_age_ranges,
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_sample_age_ranges <- function(
  data_sample_age_ranges,
  list_figure_style
) {
  validate_data_columns(
    data_source = data_sample_age_ranges,
    vec_columns_required = c(
      "dataset_name", "sample_id", "age", "age_iteration_min",
      "age_iteration_max"
    ),
    name_argument = "data_sample_age_ranges"
  )

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  vec_dataset_names <-
    data_sample_age_ranges |>
    dplyr::pull(dataset_name) |>
    base::unique()

  if (
    base::length(vec_dataset_names) != 1L
  ) {
    cli::cli_abort(
      "The sample ages must come from one dataset, not
      {base::length(vec_dataset_names)}."
    )
  }

  # Axis ends at the next multiple of 5000 years, at least 5000
  age_axis_x_max <-
    base::max(
      5000,
      base::ceiling(
        base::max(dplyr::pull(data_sample_age_ranges, age_iteration_max)) /
          5000
      ) * 5000
    )

  age_axis_y_max <-
    base::max(
      5000,
      base::ceiling(
        base::max(dplyr::pull(data_sample_age_ranges, age)) / 5000
      ) * 5000
    )

  vec_breaks_x <-
    base::seq(from = 0, to = age_axis_x_max, by = 5000)

  vec_breaks_y <-
    base::seq(from = 0, to = age_axis_y_max, by = 5000)

  res <-
    data_sample_age_ranges |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = age,
        y = age
      )
    ) +
    ggplot2::scale_x_continuous(
      breaks = vec_breaks_x,
      labels = vec_breaks_x / 1e3
    ) +
    ggplot2::scale_y_continuous(
      breaks = vec_breaks_y,
      labels = vec_breaks_y / 1e3
    ) +
    ggplot2::labs(
      y = "Sample age (ka cal yr BP)",
      x = "Potential age of Samples (ka cal yr BP)",
      caption = stringr::str_c("Dataset: ", vec_dataset_names)
    ) +
    purrr::chuck(list_figure_style, "theme") +
    ggplot2::coord_fixed(
      xlim = c(0, age_axis_x_max),
      ylim = c(0, age_axis_y_max)
    ) +
    ggplot2::geom_segment(
      mapping = ggplot2::aes(
        x = age_iteration_min,
        xend = age_iteration_max,
        yend = age
      ),
      colour = purrr::chuck(list_figure_style, "colors", "grey")
    ) +
    ggplot2::geom_point(
      shape = 21,
      fill = purrr::chuck(list_figure_style, "colors", "purple_light"),
      size = purrr::chuck(list_figure_style, "point_size"),
      colour = purrr::chuck(list_figure_style, "colors", "black")
    )

  return(res)
}
