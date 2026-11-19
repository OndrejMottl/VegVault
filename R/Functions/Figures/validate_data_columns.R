#' @title Validate that a data frame has the required columns
#' @description
#' Check that an argument is a data frame with every column a function
#' needs, and name the missing columns otherwise.
#' @param data_source
#' The object to check.
#' @param vec_columns_required
#' Character vector of the required column names.
#' @param name_argument
#' Character scalar. The name of the checked argument, used in messages.
#' @return
#' `data_source`, unchanged and invisibly.
#' @details
#' Aborts when `data_source` is not a data frame or lacks a required
#' column. Extra columns are allowed.
#' @examples
#' \dontrun{
#' validate_data_columns(
#'   data_source = data_gridpoint_links_raw,
#'   vec_columns_required = c("dataset_type", "sample_id"),
#'   name_argument = "data_gridpoint_links_raw"
#' )
#' }
validate_data_columns <- function(
  data_source,
  vec_columns_required,
  name_argument
) {
  assertthat::assert_that(
    base::is.data.frame(data_source),
    msg = stringr::str_c("`", name_argument, "` must be a data frame.")
  )

  vec_columns_missing <-
    base::setdiff(vec_columns_required, base::names(data_source))

  assertthat::assert_that(
    base::length(vec_columns_missing) == 0L,
    msg = stringr::str_c(
      "`", name_argument, "` has no column ",
      stringr::str_flatten_comma(vec_columns_missing, last = " or "),
      "."
    )
  )

  res <- data_source

  return(invisible(res))
}
