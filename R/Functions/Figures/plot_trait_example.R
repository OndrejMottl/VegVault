#' @title Plot fossil pollen datasets with the traits of their genera
#' @description
#' Combine three panels: the age range of each fossil pollen dataset, the
#' number of genera per sample, and the average trait value per genus, as
#' in the third v1 `vaultkeepr` example.
#' @param data_dataset_age_ranges
#' A data frame as returned by `summarise_dataset_age_ranges()`.
#' @param data_taxa_per_sample
#' A data frame as returned by `summarise_taxa_per_sample()`.
#' @param data_trait_by_taxon
#' A data frame as returned by `summarise_trait_by_taxon()`.
#' @param value_label
#' Character scalar. The axis title of the trait panel.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @return
#' A ggplot object made by `cowplot::plot_grid()` with the three panels in
#' one row.
#' @details
#' The age axis runs from old to young, labelled in thousands of years. The
#' y axes of the genus and trait panels start at zero and end at the data
#' (v1 cut them at 60 genera and 80 units). Aborts when a required column
#' is missing.
#' @examples
#' \dontrun{
#' fig_la_traits <-
#'   plot_trait_example(
#'     data_dataset_age_ranges = data_dataset_age_ranges,
#'     data_taxa_per_sample = data_taxa_per_sample,
#'     data_trait_by_taxon = data_trait_by_taxon,
#'     value_label = "Average Plant Height\nper genera",
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_trait_example <- function(
  data_dataset_age_ranges,
  data_taxa_per_sample,
  data_trait_by_taxon,
  value_label,
  list_figure_style
) {
  validate_data_columns(
    data_source = data_dataset_age_ranges,
    vec_columns_required = c("dataset_id", "age_min", "age_mean", "age_max"),
    name_argument = "data_dataset_age_ranges"
  )

  validate_data_columns(
    data_source = data_taxa_per_sample,
    vec_columns_required = "n_taxa",
    name_argument = "data_taxa_per_sample"
  )

  validate_data_columns(
    data_source = data_trait_by_taxon,
    vec_columns_required = "trait_value_mean",
    name_argument = "data_trait_by_taxon"
  )

  assertthat::assert_that(
    base::is.character(value_label),
    base::length(value_label) == 1L,
    !base::is.na(value_label),
    msg = "`value_label` must be a character scalar."
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

  col_grey <-
    purrr::chuck(list_figure_style, "colors", "grey")

  col_purple_light <-
    purrr::chuck(list_figure_style, "colors", "purple_light")

  # Settings shared by the two distribution panels
  theme_distribution <-
    ggplot2::theme(
      axis.title.x = ggplot2::element_blank(),
      axis.text.x = ggplot2::element_blank(),
      axis.ticks.x = ggplot2::element_blank(),
      panel.grid.major.x = ggplot2::element_blank(),
      legend.title = ggplot2::element_blank(),
      legend.position = "none"
    )

  fig_dataset_ages <-
    data_dataset_age_ranges |>
    dplyr::mutate(
      dataset_label = stats::reorder(
        x = base::factor(dataset_id),
        X = -age_mean
      )
    ) |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        y = dataset_label,
        yend = dataset_label,
        x = age_min,
        xend = age_max
      )
    ) +
    ggplot2::scale_x_continuous(
      transform = "reverse",
      breaks = scales::breaks_width(width = 2000),
      labels = scales::label_number(scale = 1e-3)
    ) +
    ggplot2::labs(
      x = "Age (ka cal yr BP)",
      y = "Datasets"
    ) +
    theme_figure +
    ggplot2::theme(
      axis.text.y = ggplot2::element_blank(),
      axis.ticks.y = ggplot2::element_blank(),
      legend.title = ggplot2::element_blank(),
      legend.position = "none",
      panel.grid.major.y = ggplot2::element_blank()
    ) +
    ggplot2::geom_segment(
      linewidth = purrr::chuck(list_figure_style, "line_size") * 10,
      colour = col_black
    ) +
    ggplot2::geom_point(
      mapping = ggplot2::aes(x = age_min),
      colour = col_purple_light,
      size = point_size
    ) +
    ggplot2::geom_point(
      mapping = ggplot2::aes(x = age_max),
      colour = col_purple_light,
      size = point_size
    )

  fig_taxa <-
    data_taxa_per_sample |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = 1,
        y = n_taxa
      )
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::label_number(),
      breaks = c(1, 5, 10, 20, 30, 50, 70),
      limits = c(0, NA)
    ) +
    ggplot2::labs(y = "N genera per Sample") +
    theme_figure +
    theme_distribution +
    ggplot2::geom_violin(
      fill = purrr::chuck(list_figure_style, "colors", "green_dark"),
      colour = col_grey
    ) +
    ggplot2::geom_boxplot(
      width = 0.2,
      outlier.shape = NA,
      fill = col_white,
      colour = col_black
    )

  fig_trait <-
    data_trait_by_taxon |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = 1,
        y = trait_value_mean
      )
    ) +
    ggplot2::scale_y_continuous(
      transform = scales::transform_pseudo_log(),
      labels = scales::label_number(),
      breaks = c(0, 1, 5, 10, 20, 30, 50, 70),
      limits = c(0, NA)
    ) +
    ggplot2::labs(y = value_label) +
    theme_figure +
    theme_distribution +
    ggplot2::geom_violin(
      fill = purrr::chuck(list_figure_style, "colors", "blue_dark"),
      colour = col_grey
    ) +
    ggplot2::geom_boxplot(
      width = 0.2,
      outlier.shape = NA,
      fill = col_white,
      colour = col_black
    )

  res <-
    cowplot::plot_grid(
      plotlist = list(fig_dataset_ages, fig_taxa, fig_trait),
      nrow = 1,
      align = "h",
      axis = "bt",
      rel_widths = c(2, 1, 1)
    )

  return(res)
}
