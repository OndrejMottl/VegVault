#' @title Prepare the positions of the fossil-pollen levels
#' @description
#' List the distinct positions of the FOSSILPOL assembly: the coordinates
#' of each dataset with the age of each of its levels.
#' @param list_data
#' A non-empty list of data frames, as the validated stage-01 target
#' `data_fossilpol_assembly` (one table per file), each with the numeric
#' columns `long` and `lat` (decimal degrees, WGS84) and the list column
#' `levels`, whose elements are data frames with the numeric column `age`
#' (calibrated years before 1950).
#' @return
#' A tibble with the double columns `coord_long`, `coord_lat` and `age`:
#' one row per distinct combination over all datasets and levels. Rows
#' with a missing value are kept, so that `prepare_link_positions()` can
#' count and drop them.
#' @details
#' The coordinates and ages are taken unchanged, as the v1.0.0 import
#' (`03_Import_fossilpol_data.R`) stores the dataset coordinates and the
#' level ages. Other columns are ignored. A dataset whose `levels` element
#' has no rows gives no position.
#' @seealso [prepare_modern_positions()], [prepare_link_positions()]
#' @examples
#' \dontrun{
#' prepare_fossilpol_positions(list_data = data_fossilpol_assembly)
#' }
prepare_fossilpol_positions <- function(list_data) {
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
        .f = ~ base::all(c("long", "lat", "levels") %in% base::names(.x)) &&
          base::is.numeric(dplyr::pull(.x, long)) &&
          base::is.numeric(dplyr::pull(.x, lat)) &&
          base::is.list(dplyr::pull(.x, levels))
      )
    ),
    msg = stringr::str_c(
      "Every table of `list_data` must have the numeric columns `long` and ",
      "`lat` and the list column `levels`."
    )
  )

  assertthat::assert_that(
    base::all(
      purrr::map_lgl(
        .x = list_data,
        .f = ~ base::all(
          purrr::map_lgl(
            .x = dplyr::pull(.x, levels),
            .f = ~ base::is.data.frame(.x) &&
              "age" %in% base::names(.x) &&
              base::is.numeric(dplyr::pull(.x, age))
          )
        )
      )
    ),
    msg = stringr::str_c(
      "Every element of `levels` must be a data frame with the numeric ",
      "column `age`."
    )
  )

  res <-
    purrr::map(
      .x = list_data,
      .f = ~ tibble::tibble(
        coord_long = base::as.double(dplyr::pull(.x, long)),
        coord_lat = base::as.double(dplyr::pull(.x, lat)),
        age = purrr::map(
          .x = dplyr::pull(.x, levels),
          .f = ~ base::as.double(dplyr::pull(.x, age))
        )
      ) |>
        tidyr::unnest_longer(col = age, keep_empty = FALSE) |>
        dplyr::distinct()
    ) |>
    purrr::list_rbind() |>
    dplyr::distinct()

  return(res)
}
