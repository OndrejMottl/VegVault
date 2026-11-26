#' @title Plot counts as a waffle chart
#' @description
#' Draw one square per `one_point_is` units of the counts in `N`, filled by
#' a category, with the number each square stands for as the caption.
#' @param data_source
#' A data frame with a numeric column `N` (the counts) and the column
#' named in `var_name`.
#' @param var_name
#' Bare column name of the category that fills the squares.
#' @param facet_var
#' Optional facetting variable (`NULL`, the default, draws one panel).
#' @param one_point_is
#' Numeric scalar. The count one square stands for; counts are divided by
#' it and rounded down.
#' @param n_rows
#' Numeric scalar. Number of rows of squares. Default `NULL`: the rounded
#' down square root of the number of squares.
#' @param plot_title
#' Character scalar. The plot title.
#' @param col_background
#' Colour of the panel background. Default: the global `col_brown_light`,
#' which the website setup (R/Website/00_Config_quarto.R) defines;
#' R looks it up where the function was sourced, not in the caller.
#' @param col_lines
#' Colour of the square borders. Default: the global `col_black`, defined
#' by the same website setup.
#' @param legend_position
#' Position of the fill legend, passed to `ggplot2::theme()`.
#' @param legend_n_col
#' Number of columns of the fill legend.
#' @param data_point_name
#' Character scalar. What the counts are, used in the caption.
#' @param theme_base
#' A complete ggplot2 theme added before the settings of the waffle, or
#' `NULL` (the default) to leave the theme to the R session, as the
#' website does.
#' @param ...
#' Passed to `waffle::geom_waffle()`.
#' @return
#' A ggplot object.
#' @details
#' The waffle hides the axes and the grid and fills the panel with
#' `col_background`, also over `theme_base`. The caption reads
#' "One square is <one_point_is> <data_point_name>", with the number
#' written with thousands separators (for example "1,000").
#' @examples
#' \dontrun{
#' plot_dataset_types <-
#'   plot_waffle(
#'     data_source = data_counts,
#'     var_name = dataset_type,
#'     one_point_is = 1e3,
#'     col_background = "#ffffff",
#'     col_lines = "#000000",
#'     theme_base = ggplot2::theme_minimal()
#'   )
#' }
plot_waffle <- function(
  data_source,
  var_name,
  facet_var = NULL,
  one_point_is = 1,
  n_rows = NULL,
  plot_title = "",
  col_background = col_brown_light, # [config]
  col_lines = col_black, # [config]
  legend_position = "right",
  legend_n_col = 1,
  data_point_name = "data points",
  theme_base = NULL,
  ...
) {
  data_work <-
    data_source %>%
    dplyr::mutate(
      N_work = floor(N / one_point_is)
    )

  n_rows_used <-
    if (
      is.null(n_rows)
    ) {
      data_work %>%
        dplyr::pull(N_work) %>%
        sum() %>%
        sqrt() %>%
        floor()
    } else {
      n_rows
    }

  plot_empty <-
    data_work %>%
    ggplot2::ggplot()

  plot_faceted <-
    if (
      isFALSE(is.null(facet_var))
    ) {
      plot_empty +
        ggplot2::facet_wrap(
          ~ {{ facet_var }},
          scales = "free_y"
        )
    } else {
      plot_empty
    }

  # The base theme goes first, so the waffle settings below stay in force;
  #   adding NULL leaves the plot unchanged
  res <-
    plot_faceted +
    ggplot2::labs(
      title = plot_title,
      fill = "",
      caption = stringr::str_c(
        "One square is",
        scales::label_comma()(one_point_is),
        data_point_name,
        sep = " "
      )
    ) +
    theme_base +
    ggplot2::guides(
      fill = ggplot2::guide_legend(ncol = legend_n_col)
    ) +
    ggplot2::theme(
      axis.title = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      axis.text = ggplot2::element_blank(),
      legend.position = legend_position,
      plot.caption.position = "panel",
      panel.background = ggplot2::element_rect(
        fill = col_background,
        colour = col_background
      ),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_blank()
    ) +
    ggplot2::coord_equal() +
    waffle::geom_waffle(
      mapping = ggplot2::aes(
        fill = {{ var_name }},
        values = N_work
      ),
      col = col_lines, # [config]
      n_rows = n_rows_used,
      make_proportional = FALSE,
      ...
    )

  return(res)
}
