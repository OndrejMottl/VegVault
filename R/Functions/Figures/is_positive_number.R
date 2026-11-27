#' @title Test whether a value is one positive number
#' @description
#' Check that a value is a single finite number greater than zero, as
#' figure sizes and widths must be.
#' @param x
#' Any R object.
#' @return
#' Logical scalar: `TRUE` when `x` is a numeric vector of length one that
#' is finite and greater than zero, otherwise `FALSE`.
#' @examples
#' \dontrun{
#' is_positive_number(x = 89)
#' }
is_positive_number <- function(x) {
  res <-
    base::is.numeric(x) &&
    base::length(x) == 1L &&
    base::is.finite(x) &&
    x > 0

  return(res)
}
