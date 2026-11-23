#' @title Compute the rows of a loaded producer artefact
#' @description
#' Count the top-level rows of a producer artefact as stage 01 hands it on,
#' over all its files, so that the database build can be checked against
#' it.
#' @param list_data
#' Named list of data frames: one data target of the producer import
#' stage, as returned by `load_producer_import()`.
#' @return
#' Number (a double, so that large artefacts do not overflow): the sum of
#' the rows of the data frames.
#' @details
#' Rows of nested elements are not counted: a plot artefact counts its
#' plots, not the taxa inside them. In the `subset` profile the data targets
#' are already cut to the box, so the count is the number the database
#' assembly receives. A table without rows counts as 0. Aborts when
#' `list_data` is not a non-empty list of data frames.
#' @seealso [build_producer_pins()]
#' @examples
#' \dontrun{
#' n_rows_try_traits <-
#'   compute_artefact_rows(list_data = data_try_traits)
#' }
compute_artefact_rows <- function(list_data) {
  assertthat::assert_that(
    base::is.list(list_data),
    !base::is.data.frame(list_data),
    base::length(list_data) > 0L,
    base::all(purrr::map_lgl(.x = list_data, .f = base::is.data.frame)),
    msg = "`list_data` must be a non-empty list of data frames."
  )

  res <-
    purrr::map_dbl(.x = list_data, .f = base::nrow) |>
    base::sum()

  return(res)
}
