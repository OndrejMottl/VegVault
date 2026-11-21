#' @title Prepare the positions of present-day samples
#' @description
#' List the distinct positions of an artefact whose samples all have age 0:
#' the vegetation plots of sPlotOpen and BIEN, and the trait records of TRY
#' and BIEN.
#' @param list_data
#' A non-empty list of data frames, each with the numeric columns
#' `longitude` and `latitude` in decimal degrees (WGS84), as the validated
#' stage-01 targets `data_splot_plots`, `data_bien_plots`,
#' `data_try_traits` and `data_bien_traits` (one table per file).
#' @return
#' A tibble with the double columns `coord_long`, `coord_lat` and `age`
#' (always 0): one row per distinct pair of `longitude` and `latitude` over
#' all tables. Pairs with a missing value are kept, so that
#' `prepare_link_positions()` can count and drop them.
#' @details
#' The coordinates are taken unchanged, as the v1.0.0 imports store them
#' as dataset coordinates (`01_Import_splot_data.R`,
#' `02_Import_bien_data.R`, `04_Import_try_data.R` and
#' `05_Import_bien_trait_data.R`), and every sample of these artefacts has
#' age 0. Other columns are ignored.
#' @seealso [prepare_fossilpol_positions()], [prepare_link_positions()]
#' @examples
#' \dontrun{
#' prepare_modern_positions(list_data = data_splot_plots)
#' }
prepare_modern_positions <- function(list_data) {
  assertthat::assert_that(
    base::is.list(list_data),
    !base::is.data.frame(list_data),
    base::length(list_data) > 0L,
    base::all(purrr::map_lgl(.x = list_data, .f = base::is.data.frame)),
    msg = "`list_data` must be a non-empty list of data frames."
  )

  assertthat::assert_that(
    base::all(
      purrr::map_lgl(
        .x = list_data,
        .f = ~ base::all(
          c("longitude", "latitude") %in% base::names(.x)
        ) &&
          base::is.numeric(dplyr::pull(.x, longitude)) &&
          base::is.numeric(dplyr::pull(.x, latitude))
      )
    ),
    msg = stringr::str_c(
      "Every table of `list_data` must have the numeric columns ",
      "`longitude` and `latitude`."
    )
  )

  res <-
    purrr::map(
      .x = list_data,
      .f = ~ tibble::tibble(
        coord_long = base::as.double(dplyr::pull(.x, longitude)),
        coord_lat = base::as.double(dplyr::pull(.x, latitude))
      ) |>
        dplyr::distinct()
    ) |>
    purrr::list_rbind() |>
    dplyr::distinct() |>
    dplyr::mutate(age = 0)

  return(res)
}
