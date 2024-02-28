plot_waffle <- function(
    data_source,
    var_name,
    facet_var = NULL,
    one_point_is = 1,
    n_rows = 10,
    plot_title = "",
    ...) {
  p0 <-
    data_source %>%
    dplyr::mutate(
      N_work = floor(N / one_point_is)
    ) %>%
    ggplot2::ggplot() +
    ggplot2::theme_bw() +
    ggplot2::guides(
      fill = ggplot2::guide_legend(ncol = 1)
    ) +
    ggplot2::theme(
      axis.title = ggplot2::element_blank(),
      axis.ticks = ggplot2::element_blank(),
      axis.text = ggplot2::element_blank(),
      legend.position = "right",
      plot.caption.position = "panel",
      strip.background = ggplot2::element_blank(),
      strip.text = ggplot2::element_text(
        size = text_size,
        hjust = 0.01
      ),
      panel.grid.minor = ggplot2::element_blank(),
      panel.grid.major = ggplot2::element_blank()
    ) +
    ggplot2::labs(
      title = plot_title,
      fill = "",
      caption = paste(
        "one square is", one_point_is, "data points"
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
      col = NA,
      n_rows = n_rows,
      make_proportional = FALSE,
      ...
    )
}
