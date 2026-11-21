#' @title Prepare the gridpoints that have a link
#' @description
#' List the gridpoints that at least one position is linked to, with their
#' coordinates, age and the v1.0.0 dataset and sample names.
#' @param data_position_links
#' A data frame with the integer column `gridpoint_id`, as returned by
#' `compute_position_links()` (other columns are ignored).
#' @param data_cells
#' The data frame of gridpoint cells that the links were computed with, as
#' returned by `prepare_gridpoint_cells()`.
#' @param vec_ages
#' The numeric vector of gridpoint ages that the links were computed with:
#' finite, distinct and sorted in increasing order.
#' @return
#' A tibble with one row per linked gridpoint, sorted by `gridpoint_id`:
#' \itemize{
#'   \item `gridpoint_id`: integer, as in `data_position_links`;
#'   \item `coord_long`, `coord_lat`: double, the rounded cell coordinates;
#'   \item `age`: double, the gridpoint age;
#'   \item `dataset_name`: `geo_<coord_long>_<coord_lat>`, the gridpoint
#'     dataset (one per cell);
#'   \item `sample_name`: `<dataset_name>_<age>`, the gridpoint sample.
#' }
#' @details
#' A gridpoint id is decoded as in `compute_position_links()`: the cell is
#' `(gridpoint_id - 1) %/% n_ages + 1` and the age index
#' `(gridpoint_id - 1) %% n_ages + 1`. Gridpoints without a link are left
#' out, as v1.0.0 stored only linked gridpoints. The numbers in the names
#' are written by `base::as.character()`, as the `paste()` of v1.0.0 did
#' (for example `geo_14.1_-0.05_500`).
#' The function aborts when a `gridpoint_id` is missing or does not belong
#' to the cells and ages.
#' @seealso [compute_position_links()], [prepare_gridpoint_cells()]
#' @examples
#' \dontrun{
#' prepare_linked_gridpoints(
#'   data_position_links = data_position_links,
#'   data_cells = data_gridpoint_cells,
#'   vec_ages = vec_chelsa_trace21k_ages
#' )
#' }
prepare_linked_gridpoints <- function(
  data_position_links,
  data_cells,
  vec_ages
) {
  assertthat::assert_that(
    base::is.data.frame(data_position_links),
    "gridpoint_id" %in% base::names(data_position_links),
    msg = stringr::str_c(
      "`data_position_links` must be a data frame with the column ",
      "`gridpoint_id`."
    )
  )

  assertthat::assert_that(
    base::is.integer(dplyr::pull(data_position_links, gridpoint_id)),
    msg = "`gridpoint_id` of `data_position_links` must be an integer."
  )

  assertthat::assert_that(
    base::is.data.frame(data_cells),
    base::all(
      c("cell_index", "coord_long", "coord_lat") %in% base::names(data_cells)
    ),
    base::nrow(data_cells) > 0L,
    msg = stringr::str_c(
      "`data_cells` must be a non-empty data frame with the columns ",
      "`cell_index`, `coord_long` and `coord_lat`."
    )
  )

  assertthat::assert_that(
    base::identical(
      dplyr::pull(data_cells, cell_index),
      base::seq_len(base::nrow(data_cells))
    ),
    base::is.numeric(dplyr::pull(data_cells, coord_long)),
    base::is.numeric(dplyr::pull(data_cells, coord_lat)),
    msg = stringr::str_c(
      "`data_cells` must number its rows with the integers 1 to n in ",
      "`cell_index` and have numeric coordinates."
    )
  )

  assertthat::assert_that(
    base::is.numeric(vec_ages),
    base::length(vec_ages) > 0L,
    base::all(base::is.finite(vec_ages)),
    !base::is.unsorted(vec_ages, strictly = TRUE),
    msg = "`vec_ages` must hold finite, distinct ages in increasing order."
  )

  n_ages <-
    base::length(vec_ages)

  n_gridpoints <-
    base::as.double(base::nrow(data_cells)) * n_ages

  vec_gridpoint_ids <-
    data_position_links |>
    dplyr::distinct(gridpoint_id) |>
    dplyr::pull(gridpoint_id)

  vec_unknown_ids <-
    vec_gridpoint_ids[
      base::is.na(vec_gridpoint_ids) |
        vec_gridpoint_ids < 1L |
        vec_gridpoint_ids > n_gridpoints
    ]

  if (
    base::length(vec_unknown_ids) > 0L
  ) {
    cli::cli_abort(
      c(
        "{base::length(vec_unknown_ids)} {.field gridpoint_id} value{?s} \\
        {?is/are} not a gridpoint of the {base::nrow(data_cells)} cells \\
        and {n_ages} ages.",
        "x" = "For example: {.val {utils::head(vec_unknown_ids, n = 5L)}}."
      )
    )
  }

  res <-
    tibble::tibble(
      gridpoint_id = base::sort(vec_gridpoint_ids)
    ) |>
    dplyr::mutate(
      cell_index = (gridpoint_id - 1L) %/% n_ages + 1L,
      age_index = (gridpoint_id - 1L) %% n_ages + 1L
    ) |>
    dplyr::inner_join(
      dplyr::select(data_cells, cell_index, coord_long, coord_lat),
      by = dplyr::join_by(cell_index),
      multiple = "error",
      unmatched = c("error", "drop")
    ) |>
    dplyr::mutate(
      age = base::as.double(vec_ages)[age_index],
      # as.character() writes the numbers as the paste() of v1.0.0 did
      dataset_name = stringr::str_c(
        "geo",
        base::as.character(coord_long),
        base::as.character(coord_lat),
        sep = "_"
      ),
      sample_name = stringr::str_c(
        dataset_name,
        base::as.character(age),
        sep = "_"
      )
    ) |>
    dplyr::select(
      gridpoint_id, coord_long, coord_lat, age, dataset_name, sample_name
    )

  return(res)
}
