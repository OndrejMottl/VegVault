#' @title Compute the links between positions and gridpoints
#' @description
#' Find, for every position of a chunk, the gridpoints within the link
#' distance and the link age difference, with the v1.0.0 rule applied
#' verbatim.
#' @param data_windows
#' A data frame of search windows, as one element of the result of
#' `build_link_windows()`: the integer column `position_id` and the
#' numeric columns `coord_long`, `coord_lat`, `age`, `lat_lo`, `lat_hi`,
#' `lon_lo` and `lon_hi`.
#' @param data_cells
#' A data frame of gridpoint cells, as returned by
#' `prepare_gridpoint_cells()`: the integer column `cell_index` (1 to the
#' number of cells, in row order) and the numeric columns `coord_long` and
#' `coord_lat`.
#' @param vec_ages
#' A numeric vector of the gridpoint ages: finite, distinct and sorted in
#' increasing order, such as the stage-01 target `vec_chelsa_trace21k_ages`.
#' @param distance_km
#' A positive number: the link distance in km (v1.0.0: 50).
#' @param distance_years
#' A number, at least 0: the link age difference in years (v1.0.0: 5000).
#' @param age_margin_years
#' A number, at least 0: years added to `distance_years` in the age join,
#' which only selects candidates for the exact age test.
#' @return
#' A tibble with one row per link, sorted by `position_id` and then
#' `gridpoint_id`, with the integer columns:
#' \itemize{
#'   \item `position_id`: the position, as in `data_windows`;
#'   \item `gridpoint_id`: the gridpoint, `(cell_index - 1) * n_ages +
#'     age_index`, where `n_ages` is the length of `vec_ages` and
#'     `age_index` the position of the gridpoint age in it, so the ids
#'     order the gridpoints by longitude, latitude and age;
#'   \item `distance_in_km`, `distance_in_years`: the distance and the
#'     absolute age difference, truncated to whole numbers.
#' }
#' @details
#' A gridpoint is a cell at one of the ages. A position and a gridpoint
#' are linked when
#' `geosphere::distGeo(p1, p2) / 1e3 <= distance_km` and
#' `abs(age - grid_age) <= distance_years`, both applied verbatim as in
#' the gridpoint links of v1.0.0, with `p1` the position and `p2` the
#' rounded cell coordinates in that order; the distance is the geodesic on
#' the WGS84 ellipsoid. The distance and the age difference are truncated
#' with `base::as.integer()`, as the v1.0.0 writer did.
#' Only the cells inside a window of the position are tested, and only the
#' ages within `distance_years + age_margin_years` of the position age.
#' Because the windows of `build_link_windows()` contain every point
#' within the distance, the links are the same as a test of every cell,
#' including the high latitudes, where 50 km exceed one degree of
#' longitude, and across the dateline; v1.0.0 missed those links.
#' Each position is linked on its own, so the result for a set of
#' positions does not depend on how they are split into chunks.
#' The function aborts when the number of gridpoints exceeds the largest
#' integer.
#' @seealso [build_link_windows()], [prepare_gridpoint_cells()],
#' [prepare_linked_gridpoints()]
#' @examples
#' \dontrun{
#' compute_position_links(
#'   data_windows = purrr::chuck(list_link_windows, 1L),
#'   data_cells = data_gridpoint_cells,
#'   vec_ages = vec_chelsa_trace21k_ages,
#'   distance_km = 50,
#'   distance_years = 5000,
#'   age_margin_years = 1
#' )
#' }
compute_position_links <- function(
  data_windows,
  data_cells,
  vec_ages,
  distance_km,
  distance_years,
  age_margin_years
) {
  vec_window_columns <-
    c(
      "position_id", "coord_long", "coord_lat", "age",
      "lat_lo", "lat_hi", "lon_lo", "lon_hi"
    )

  assertthat::assert_that(
    base::is.data.frame(data_windows),
    base::all(vec_window_columns %in% base::names(data_windows)),
    msg = stringr::str_c(
      "`data_windows` must be a data frame with the columns ",
      "`position_id`, `coord_long`, `coord_lat`, `age`, `lat_lo`, ",
      "`lat_hi`, `lon_lo` and `lon_hi`."
    )
  )

  assertthat::assert_that(
    base::is.integer(dplyr::pull(data_windows, position_id)),
    base::all(
      purrr::map_lgl(
        .x = dplyr::select(
          data_windows,
          dplyr::all_of(vec_window_columns[-1L])
        ),
        .f = ~ base::is.numeric(.x) && !base::anyNA(.x)
      )
    ),
    msg = stringr::str_c(
      "`data_windows` must have an integer `position_id` and numeric ",
      "coordinates, ages and bounds without missing values."
    )
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
    !base::anyNA(dplyr::pull(data_cells, coord_long)),
    !base::anyNA(dplyr::pull(data_cells, coord_lat)),
    msg = stringr::str_c(
      "`data_cells` must number its rows with the integers 1 to n in ",
      "`cell_index` and have numeric coordinates without missing values."
    )
  )

  assertthat::assert_that(
    base::is.numeric(vec_ages),
    base::length(vec_ages) > 0L,
    base::all(base::is.finite(vec_ages)),
    !base::is.unsorted(vec_ages, strictly = TRUE),
    msg = "`vec_ages` must hold finite, distinct ages in increasing order."
  )

  assertthat::assert_that(
    base::is.numeric(distance_km),
    base::length(distance_km) == 1L,
    base::is.finite(distance_km),
    distance_km > 0,
    msg = "`distance_km` must be a positive number."
  )

  assertthat::assert_that(
    base::is.numeric(distance_years),
    base::length(distance_years) == 1L,
    base::is.finite(distance_years),
    distance_years >= 0,
    msg = "`distance_years` must be a number, at least 0."
  )

  assertthat::assert_that(
    base::is.numeric(age_margin_years),
    base::length(age_margin_years) == 1L,
    base::is.finite(age_margin_years),
    age_margin_years >= 0,
    msg = "`age_margin_years` must be a number, at least 0."
  )

  n_ages <-
    base::length(vec_ages)

  n_gridpoints <-
    base::as.double(base::nrow(data_cells)) * n_ages

  if (
    n_gridpoints > purrr::chuck(base::.Machine, "integer.max")
  ) {
    cli::cli_abort(
      c(
        "The grid has {n_gridpoints} gridpoints, more than the largest \\
        integer.",
        "i" = "Gridpoint ids are integers; use fewer cells or ages."
      )
    )
  }

  data_ages <-
    tibble::tibble(
      age_index = base::seq_len(n_ages),
      grid_age = base::as.double(vec_ages)
    )

  data_windows_selected <-
    dplyr::select(data_windows, dplyr::all_of(vec_window_columns))

  # Only cells inside the bounds of all windows can match one of them
  data_cells_near <-
    data_cells |>
    dplyr::select(
      cell_index,
      grid_long = coord_long,
      grid_lat = coord_lat
    ) |>
    dplyr::filter(
      grid_lat >= base::min(dplyr::pull(data_windows_selected, lat_lo)),
      grid_lat <= base::max(dplyr::pull(data_windows_selected, lat_hi)),
      grid_long >= base::min(dplyr::pull(data_windows_selected, lon_lo)),
      grid_long <= base::max(dplyr::pull(data_windows_selected, lon_hi))
    )

  data_candidates <-
    data_cells_near |>
    dplyr::inner_join(
      data_windows_selected,
      by = dplyr::join_by(
        dplyr::between(grid_lat, lat_lo, lat_hi),
        dplyr::between(grid_long, lon_lo, lon_hi)
      ),
      relationship = "many-to-many"
    ) |>
    dplyr::distinct(position_id, cell_index, .keep_all = TRUE)

  # The v1.0.0 distance test, verbatim (position first, then the cell)
  data_near <-
    data_candidates |>
    dplyr::mutate(
      distance_in_km_exact = geosphere::distGeo(
        p1 = base::cbind(coord_long, coord_lat),
        p2 = base::cbind(grid_long, grid_lat)
      ) / 1e3
    ) |>
    dplyr::filter(distance_in_km_exact <= distance_km) |>
    dplyr::mutate(
      age_lo = age - distance_years - age_margin_years,
      age_hi = age + distance_years + age_margin_years
    )

  # The v1.0.0 age test, verbatim, on the ages that the join selects
  res <-
    data_ages |>
    dplyr::inner_join(
      data_near,
      by = dplyr::join_by(dplyr::between(grid_age, age_lo, age_hi)),
      relationship = "many-to-many"
    ) |>
    dplyr::mutate(
      distance_in_years_exact = base::abs(age - grid_age)
    ) |>
    dplyr::filter(distance_in_years_exact <= distance_years) |>
    dplyr::mutate(
      gridpoint_id = (cell_index - 1L) * n_ages + age_index,
      distance_in_km = base::as.integer(distance_in_km_exact),
      distance_in_years = base::as.integer(distance_in_years_exact)
    ) |>
    dplyr::select(
      position_id, gridpoint_id, distance_in_km, distance_in_years
    ) |>
    dplyr::arrange(position_id, gridpoint_id)

  return(res)
}
