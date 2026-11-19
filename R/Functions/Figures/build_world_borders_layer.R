#' @title Build a ggplot2 layer of the world's country outlines
#' @description
#' Return a polygon layer of the countries of the `maps` package, the same
#' outlines that `ggplot2::borders()` drew in the v1 figures.
#' @param col_fill
#' Fill colour of the land, or `NA` for none.
#' @param col_line
#' Colour of the country borders, or `NA` for none.
#' @param linewidth
#' Positive numeric scalar. Width of the border lines.
#' @return
#' A ggplot2 layer (`geom_polygon()`) with its own data and aesthetics, so
#' that it can be added to any longitude-latitude plot, also a facetted one.
#' @details
#' `ggplot2::annotation_borders()`, which replaces the deprecated
#' `borders()` in ggplot2 4.0, fails in facetted plots; this layer does
#' not.
#' @examples
#' \dontrun{
#' layer_land <-
#'   build_world_borders_layer(
#'     col_fill = "#999999",
#'     col_line = NA,
#'     linewidth = 0.05
#'   )
#' }
build_world_borders_layer <- function(
  col_fill,
  col_line,
  linewidth
) {
  assertthat::assert_that(
    base::length(col_fill) == 1L,
    base::is.character(col_fill) || base::is.na(col_fill),
    msg = "`col_fill` must be one colour or NA."
  )

  assertthat::assert_that(
    base::length(col_line) == 1L,
    base::is.character(col_line) || base::is.na(col_line),
    msg = "`col_line` must be one colour or NA."
  )

  assertthat::assert_that(
    is_positive_number(linewidth),
    msg = "`linewidth` must be a positive number."
  )

  data_world <-
    ggplot2::map_data(map = "world")

  res <-
    ggplot2::geom_polygon(
      data = data_world,
      mapping = ggplot2::aes(
        x = long,
        y = lat,
        group = group
      ),
      inherit.aes = FALSE,
      fill = col_fill,
      colour = col_line,
      linewidth = linewidth
    )

  return(res)
}
