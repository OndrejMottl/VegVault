#' @title Prepare the ages of the CHELSA-TraCE21k time slices
#' @description
#' Convert the time slices of a validated CHELSA-TraCE21k variable into the
#' ages, in years before 1950, at which the gridpoint stage creates
#' gridpoints.
#' @param list_data
#' Named list of data frames with the column `time_id` (text holding a
#' whole number), as returned by `load_producer_import()`.
#' @return
#' Numeric vector of the distinct ages, sorted in increasing order.
#' @details
#' The age is `-time_id * 100 + 2000`, as the contract of
#' `chelsa_trace21k_palaeoclimate` documents. Missing time slices are
#' dropped. Aborts when a table lacks `time_id` or a value is not a number.
#' @examples
#' \dontrun{
#' prepare_chelsa_trace21k_ages(
#'   list_data = data_chelsa_trace21k_palaeoclimate_bio1
#' )
#' }
prepare_chelsa_trace21k_ages <- function(list_data) {
  assertthat::assert_that(
    base::is.list(list_data),
    !base::is.data.frame(list_data),
    base::length(list_data) > 0L,
    base::all(purrr::map_lgl(.x = list_data, .f = base::is.data.frame)),
    msg = "`list_data` must be a non-empty list of data frames."
  )

  vec_time_ids <-
    purrr::map(
      .x = list_data,
      .f = ~ dplyr::pull(.x, var = "time_id")
    ) |>
    purrr::list_c() |>
    base::unique()

  vec_time_ids <-
    vec_time_ids[!base::is.na(vec_time_ids)]

  vec_not_number <-
    vec_time_ids[!stringr::str_detect(vec_time_ids, "^-?[0-9]+$")]

  if (
    base::length(vec_not_number) > 0L
  ) {
    cli::cli_abort(
      "{.field time_id} must hold whole numbers, not {.val {vec_not_number}}."
    )
  }

  res <-
    (-base::as.numeric(vec_time_ids) * 100 + 2000) |>
    base::unique() |>
    base::sort()

  return(res)
}
