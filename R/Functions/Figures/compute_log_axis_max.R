#' @title Compute the upper limit of a log10 count axis
#' @description
#' Return the power of ten one decade above the largest count, so that the
#' count labels drawn above the points fit in the panel.
#' @param n_max
#' Positive numeric scalar. The largest count on the axis.
#' @return
#' Numeric scalar: `10^(ceiling(log10(n_max)) + 1)`.
#' @details
#' For counts between 100,000 and 1 million this is 10 million, the fixed
#' limit of the v1 dataset figure.
#' @examples
#' \dontrun{
#' compute_log_axis_max(n_max = 950000)
#' }
compute_log_axis_max <- function(n_max) {
  assertthat::assert_that(
    is_positive_number(n_max),
    msg = "`n_max` must be a positive number."
  )

  res <-
    10^(base::ceiling(base::log10(n_max)) + 1)

  return(res)
}
