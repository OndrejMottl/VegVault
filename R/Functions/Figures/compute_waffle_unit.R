#' @title Compute how many records one waffle square stands for
#' @description
#' Choose the power of ten of records per square that draws a total count
#' as 100 to 1000 squares.
#' @param n_total
#' Positive numeric scalar. The number of records drawn in the waffle.
#' @return
#' Numeric scalar: a power of ten, at least 1.
#' @details
#' The unit is `10^floor(log10(n_total / 100))`, but never below one
#' record, so fewer than 100 records give one square each. For the 426,225
#' datasets of v1 this is 1000 datasets per square, the fixed unit of the
#' v1 figure.
#' @examples
#' \dontrun{
#' compute_waffle_unit(n_total = 426225)
#' }
compute_waffle_unit <- function(n_total) {
  assertthat::assert_that(
    is_positive_number(n_total),
    msg = "`n_total` must be a positive number."
  )

  res <-
    base::max(
      1,
      10^base::floor(base::log10(n_total / 100))
    )

  return(res)
}
