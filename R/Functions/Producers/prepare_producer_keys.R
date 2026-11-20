#' @title Prepare the key values kept in a producer artefact
#' @description
#' List the distinct values of one key column over every table of a
#' validated artefact, such as the dataset IDs the FOSSILPOL assembly kept
#' in the subset box. Another artefact is then cut to these keys without
#' loading the whole reference artefact.
#' @param list_data
#' Named list of data frames, as returned by `load_producer_import()`.
#' @param col_key
#' Character scalar. Name of the key column.
#' @return
#' A vector of the distinct, non-missing key values, sorted, with the type
#' of the column.
#' @details
#' Aborts when `list_data` is empty or a table lacks `col_key`.
#' @examples
#' \dontrun{
#' prepare_producer_keys(
#'   list_data = data_fossilpol_assembly,
#'   col_key = "dataset_id"
#' )
#' }
prepare_producer_keys <- function(
  list_data,
  col_key
) {
  assertthat::assert_that(
    base::is.list(list_data),
    !base::is.data.frame(list_data),
    base::length(list_data) > 0L,
    base::all(purrr::map_lgl(.x = list_data, .f = base::is.data.frame)),
    msg = "`list_data` must be a non-empty list of data frames."
  )

  assertthat::assert_that(
    base::is.character(col_key),
    base::length(col_key) == 1L,
    !base::is.na(col_key),
    msg = "`col_key` must be a character scalar."
  )

  res <-
    purrr::map(
      .x = list_data,
      .f = ~ dplyr::pull(.x, var = col_key)
    ) |>
    purrr::list_c() |>
    base::unique() |>
    base::sort()

  return(res)
}
