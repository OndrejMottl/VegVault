#' @title Plot the number of taxa per classification level
#' @description
#' Draw a labelled lollipop chart of the taxa per classification level, as
#' in the v1 taxa figure.
#' @param data_taxa_classification_counts
#' A data frame as returned by `load_taxa_classification_counts()`, with
#' the columns `taxon_level` and `n_taxa`.
#' @param list_figure_style
#' Named list, as returned by `build_figure_style()`.
#' @return
#' A ggplot object with the levels in the order of the data.
#' @details
#' The y axis reaches 20 percent above the largest count, to leave room
#' for the labels (v1: fixed at 120,000). The axis and the labels write
#' the counts with comma thousands separators. Aborts when a required
#' column is missing.
#' @examples
#' \dontrun{
#' fig_n_taxa_per_class <-
#'   plot_taxa_classification(
#'     data_taxa_classification_counts = data_taxa_classification_counts,
#'     list_figure_style = list_figure_style
#'   )
#' }
plot_taxa_classification <- function(
  data_taxa_classification_counts,
  list_figure_style
) {
  validate_data_columns(
    data_source = data_taxa_classification_counts,
    vec_columns_required = c("taxon_level", "n_taxa"),
    name_argument = "data_taxa_classification_counts"
  )

  assertthat::assert_that(
    base::is.list(list_figure_style),
    msg = "`list_figure_style` must be the list of build_figure_style()."
  )

  point_size <-
    purrr::chuck(list_figure_style, "point_size")

  col_black <-
    purrr::chuck(list_figure_style, "colors", "black")

  data_counts_ordered <-
    data_taxa_classification_counts |>
    dplyr::mutate(
      taxon_level = base::factor(
        taxon_level,
        levels = base::unique(taxon_level)
      )
    )

  # Room above the largest count for its label
  n_axis_max <-
    base::max(dplyr::pull(data_counts_ordered, n_taxa)) * 1.2

  position_lollipop <-
    ggplot2::position_dodge(width = 0.5)

  res <-
    data_counts_ordered |>
    ggplot2::ggplot(
      mapping = ggplot2::aes(
        x = taxon_level,
        y = n_taxa
      )
    ) +
    ggplot2::scale_y_continuous(
      labels = scales::label_comma()
    ) +
    ggplot2::labs(
      x = NULL,
      y = "Number of Taxa"
    ) +
    purrr::chuck(list_figure_style, "theme") +
    ggplot2::theme(
      panel.grid.major.x = ggplot2::element_blank()
    ) +
    ggplot2::coord_cartesian(
      ylim = c(0, n_axis_max)
    ) +
    ggplot2::geom_segment(
      mapping = ggplot2::aes(
        xend = taxon_level,
        yend = 0
      ),
      colour = col_black,
      position = position_lollipop
    ) +
    ggplot2::geom_point(
      size = point_size,
      colour = col_black,
      position = position_lollipop
    ) +
    ggplot2::geom_label(
      mapping = ggplot2::aes(label = scales::comma(n_taxa)),
      vjust = -0.5,
      size = point_size * 2,
      position = position_lollipop
    )

  return(res)
}
