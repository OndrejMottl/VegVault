plot_waffle <- function(
    data_source,
    var_name,
    facet_var = NULL,
    one_point_is = 1,
    n_rows = NULL,
    plot_title = "",
    col_background = col_brown_light, # [config]
    col_lines = col_blue_dark, # [config]
    legend_position = "right",
    legend_n_col = 1,
    data_point_name = "data points",
    ...) {
  data_work <-
    data_source %>%
    dplyr::mutate(
      N_work = floor(N / one_point_is)
    )

  if (
    is.null(n_rows)
  ) {
    n_rows <-
      sum(data_work$N_work) %>%
      sqrt() %>%
      floor()
  }

  p0 <-
    data_work %>%
    ggplot2::ggplot() +
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
    ggplot2::labs(
      title = plot_title,
      fill = "",
      caption = paste(
        "one square is", one_point_is, data_point_name
      )
    )

  if (
    isFALSE(is.null(facet_var))
  ) {
    p0 <-
      p0 +
      ggplot2::facet_wrap(
        ~ {{ facet_var }},
        scales = "free_y"
      )
  }
  p0 +
    ggplot2::coord_equal() +
    waffle::geom_waffle(
      mapping = ggplot2::aes(
        fill = {{ var_name }},
        values = N_work
      ),
      col = col_lines, # [config]
      n_rows = n_rows,
      make_proportional = FALSE,
      ...
    )
}
