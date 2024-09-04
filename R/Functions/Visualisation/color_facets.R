#' @description
#' A helper function to colour the facets
color_facets <- function(sel_plot,
                         sel_palette,
                         direction = c("vertical", "horizontal"),
                         return_raw = FALSE) {
  direction <- match.arg(direction)
  g <-
    ggplot2::ggplot_gtable(
      ggplot2::ggplot_build(sel_plot)
    )
  stripr <-
    which(grepl("strip-t", g$layout$name))

  for (i in seq_along(stripr)) {
    object_val <-
      sort(stripr,
        decreasing = ifelse(direction == "vertical",
          TRUE,
          FALSE
        )
      )[i]

    j <-
      which(grepl("rect", g$grobs[[object_val]]$grobs[[1]]$childrenOrder))

    g$grobs[[object_val]]$grobs[[1]]$children[[j]]$gp$fill <-
      sel_palette[i]
  }

  if (
    return_raw == TRUE
  ) {
    return(g)
  } else {
    grid::grid.draw(g)
  }
}
