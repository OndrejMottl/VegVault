#' @title Colour the facet strips of a plot
#' @description
#' Build the gtable of a facetted ggplot and fill its top facet strips with
#' the given colours, one per strip.
#' @param sel_plot
#' A ggplot object facetted with strips on top (for example
#' `ggplot2::facet_wrap()`).
#' @param sel_palette
#' Character vector of colours, one per strip.
#' @param direction
#' `"vertical"` (default) gives the first colour to the strip drawn last,
#' `"horizontal"` to the strip drawn first; use `"horizontal"` for one row
#' of panels, so that the colours follow the panels from left to right.
#' @param return_raw
#' Logical. `TRUE` returns the gtable; `FALSE` (default) draws it on the
#' current graphics device.
#' @return
#' The gtable with coloured strips when `return_raw` is `TRUE`; otherwise
#' the value of `grid::grid.draw()` (`NULL`, invisibly), after drawing.
#' @examples
#' \dontrun{
#' grob_coloured <-
#'   build_coloured_facet_strips(
#'     sel_plot = plot_facetted,
#'     sel_palette = c("#3ddc47", "#aa6da3"),
#'     direction = "horizontal",
#'     return_raw = TRUE
#'   )
#' }
build_coloured_facet_strips <- function(
  sel_plot,
  sel_palette,
  direction = c("vertical", "horizontal"),
  return_raw = FALSE
) {
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
