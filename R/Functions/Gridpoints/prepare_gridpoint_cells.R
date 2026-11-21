#' @title Prepare the cells of the gridpoints
#' @description
#' Combine the coordinates of the gridded climate artefacts into the cells
#' at which gridpoints are created: rounded, distinct and numbered.
#' @param list_coordinates
#' A non-empty list of data frames, each with the numeric columns `long`
#' and `lat` in decimal degrees (WGS84), such as the stage-01 targets
#' `data_chelsa_trace21k_coordinates` and
#' `data_chelsa_neoclimate_coordinates`.
#' @param n_digits
#' A whole number, at least 0: the number of decimals the coordinates are
#' rounded to. Default: 2, as in v1.0.0.
#' @return
#' A tibble with one row per cell, sorted by `coord_long` and then
#' `coord_lat`:
#' \itemize{
#'   \item `cell_index`: integer, the row number (1 to the number of cells);
#'   \item `coord_long`, `coord_lat`: double, the rounded coordinates.
#' }
#' @details
#' As in v1.0.0 (`06_Create_gridpoints.R`), the coordinates are rounded with
#' `base::round()`, the sets are combined, and every distinct rounded pair
#' becomes one cell; pairs with a missing value are dropped. Coordinates
#' that round to the same pair give one cell. The soil grid is not a source
#' of cells, as in v1.0.0.
#' The function aborts when a rounded coordinate lies outside -180 to 180
#' (longitude) or -90 to 90 (latitude), or when no cell remains.
#' @seealso [compute_position_links()], [prepare_linked_gridpoints()]
#' @examples
#' \dontrun{
#' prepare_gridpoint_cells(
#'   list_coordinates = list(
#'     data_chelsa_trace21k_coordinates,
#'     data_chelsa_neoclimate_coordinates
#'   )
#' )
#' }
prepare_gridpoint_cells <- function(
  list_coordinates,
  n_digits = 2L
) {
  assertthat::assert_that(
    base::is.list(list_coordinates),
    !base::is.data.frame(list_coordinates),
    base::length(list_coordinates) > 0L,
    base::all(
      purrr::map_lgl(.x = list_coordinates, .f = base::is.data.frame)
    ),
    msg = "`list_coordinates` must be a non-empty list of data frames."
  )

  assertthat::assert_that(
    base::all(
      purrr::map_lgl(
        .x = list_coordinates,
        .f = ~ base::all(c("long", "lat") %in% base::names(.x)) &&
          base::is.numeric(dplyr::pull(.x, long)) &&
          base::is.numeric(dplyr::pull(.x, lat))
      )
    ),
    msg = stringr::str_c(
      "Every table of `list_coordinates` must have the numeric columns ",
      "`long` and `lat`."
    )
  )

  assertthat::assert_that(
    base::is.numeric(n_digits),
    base::length(n_digits) == 1L,
    !base::is.na(n_digits),
    n_digits >= 0,
    n_digits == base::round(n_digits),
    msg = "`n_digits` must be a whole number, at least 0."
  )

  data_cells_rounded <-
    purrr::map(
      .x = list_coordinates,
      .f = ~ tibble::tibble(
        coord_long = base::round(
          x = base::as.double(dplyr::pull(.x, long)),
          digits = n_digits
        ),
        coord_lat = base::round(
          x = base::as.double(dplyr::pull(.x, lat)),
          digits = n_digits
        )
      )
    ) |>
    purrr::list_rbind() |>
    tidyr::drop_na() |>
    dplyr::distinct()

  data_outside <-
    data_cells_rounded |>
    dplyr::filter(
      !(coord_long >= -180 & coord_long <= 180 &
        coord_lat >= -90 & coord_lat <= 90)
    )

  if (
    base::nrow(data_outside) > 0L
  ) {
    vec_outside <-
      data_outside |>
      utils::head(n = 5L) |>
      dplyr::mutate(
        pair = stringr::str_glue("({coord_long}, {coord_lat})")
      ) |>
      dplyr::pull(pair)

    cli::cli_abort(
      c(
        "{base::nrow(data_outside)} cell{?s} lie{?s/} outside -180 to 180 \\
        (longitude) or -90 to 90 (latitude).",
        "i" = "For example: {vec_outside}."
      )
    )
  }

  if (
    base::nrow(data_cells_rounded) == 0L
  ) {
    cli::cli_abort("No cell remains after dropping missing coordinates.")
  }

  res <-
    data_cells_rounded |>
    dplyr::arrange(coord_long, coord_lat) |>
    dplyr::mutate(
      cell_index = dplyr::row_number(),
      .before = 1L
    )

  return(res)
}
