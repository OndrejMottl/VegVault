#' @title Prepare the coordinates of a gridded climate artefact
#' @description
#' List the distinct coordinates of a validated gridded artefact, such as
#' one CHELSA variable, so that the gridpoint stage gets its grid without
#' loading the climate values.
#' @param list_data
#' Named list of data frames with the numeric columns `long` and `lat`, as
#' returned by `load_producer_import()`.
#' @return
#' A tibble with the numeric columns `long` and `lat`: one row per distinct
#' pair, without missing values, sorted by `long` and then `lat`.
#' @details
#' The coordinates are not rounded; the gridpoint stage rounds them when it
#' names gridpoints. Aborts when a table lacks `long` or `lat`.
#' @examples
#' \dontrun{
#' prepare_climate_coordinates(
#'   list_data = data_chelsa_trace21k_palaeoclimate_bio1
#' )
#' }
prepare_climate_coordinates <- function(list_data) {
  assertthat::assert_that(
    base::is.list(list_data),
    !base::is.data.frame(list_data),
    base::length(list_data) > 0L,
    base::all(purrr::map_lgl(.x = list_data, .f = base::is.data.frame)),
    msg = "`list_data` must be a non-empty list of data frames."
  )

  res <-
    purrr::map(
      .x = list_data,
      .f = ~ dplyr::select(.x, dplyr::all_of(c("long", "lat")))
    ) |>
    dplyr::bind_rows() |>
    dplyr::distinct() |>
    tidyr::drop_na() |>
    dplyr::arrange(long, lat) |>
    tibble::as_tibble()

  return(res)
}
