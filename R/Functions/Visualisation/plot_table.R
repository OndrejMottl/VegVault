plot_table <- function(data_source) {
  assertthat::assert_that(
    is.data.frame(data_source),
    msg = "data_source must be a data frame"
  )

  n_row  <- nrow(data_source)

  if (
    n_row > 0
  ) {
    tinytable::tt(data_source)
  }
}