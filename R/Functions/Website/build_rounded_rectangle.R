#' @title Build the outline of a rectangle with rounded corners
#' @description
#' Compute the points of a rectangle whose corners are quarter circles, as
#' a polygon for `ggplot2::geom_polygon()`.
#' @param x
#' Numeric scalar. Horizontal centre of the rectangle.
#' @param y
#' Numeric scalar. Vertical centre of the rectangle.
#' @param width
#' Positive numeric scalar. Width of the rectangle.
#' @param height
#' Positive numeric scalar. Height of the rectangle.
#' @param radius
#' Non-negative numeric scalar. Radius of the corners, at most half of
#' the shorter side.
#' @param n_corner
#' Integer scalar of at least 2. Number of points of each corner arc.
#' Default: 10.
#' @return
#' A tibble with the columns `x` and `y` and `4 * n_corner` rows: the arcs
#' of the corners in the order top right, top left, bottom left and bottom
#' right, counter-clockwise, without repeating the first point.
#' @details
#' The rectangle spans exactly `x - width / 2` to `x + width / 2` and
#' `y - height / 2` to `y + height / 2`. With `radius` 0, each corner arc
#' collapses to its corner point, repeated `n_corner` times. Aborts when an
#' argument is not a single finite number or out of its range.
#' @examples
#' \dontrun{
#' data_box <-
#'   build_rounded_rectangle(
#'     x = 0, y = 0, width = 4, height = 2, radius = 0.4
#'   )
#' }
build_rounded_rectangle <- function(
  x,
  y,
  width,
  height,
  radius,
  n_corner = 10L
) {
  assertthat::assert_that(
    rlang::is_scalar_double(x) || rlang::is_scalar_integer(x),
    base::is.finite(x),
    msg = "`x` must be one finite number."
  )

  assertthat::assert_that(
    rlang::is_scalar_double(y) || rlang::is_scalar_integer(y),
    base::is.finite(y),
    msg = "`y` must be one finite number."
  )

  assertthat::assert_that(
    base::is.numeric(width),
    base::length(width) == 1L,
    base::is.finite(width),
    width > 0,
    msg = "`width` must be one positive number."
  )

  assertthat::assert_that(
    base::is.numeric(height),
    base::length(height) == 1L,
    base::is.finite(height),
    height > 0,
    msg = "`height` must be one positive number."
  )

  assertthat::assert_that(
    base::is.numeric(radius),
    base::length(radius) == 1L,
    base::is.finite(radius),
    radius >= 0,
    radius <= base::min(width, height) / 2,
    msg = "`radius` must be between 0 and half of the shorter side."
  )

  assertthat::assert_that(
    rlang::is_integerish(n_corner, n = 1L, finite = TRUE),
    n_corner >= 2,
    msg = "`n_corner` must be a whole number of at least 2."
  )

  # Centres of the corner arcs and the angle each arc starts at, in the
  #   counter-clockwise order top right, top left, bottom left, bottom right
  data_corners <-
    tibble::tibble(
      centre_x = x + c(1, -1, -1, 1) * (width / 2 - radius),
      centre_y = y + c(1, 1, -1, -1) * (height / 2 - radius),
      angle_start = c(0, 0.5, 1, 1.5) * base::pi
    )

  vec_steps <-
    base::seq(from = 0, to = base::pi / 2, length.out = n_corner)

  res <-
    purrr::pmap(
      .l = data_corners,
      .f = ~ tibble::tibble(
        x = ..1 + radius * base::cos(..3 + vec_steps),
        y = ..2 + radius * base::sin(..3 + vec_steps)
      )
    ) |>
    dplyr::bind_rows()

  return(res)
}
