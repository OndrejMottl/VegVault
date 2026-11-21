#' @title Select a stratified sample of positions for the link check
#' @description
#' Read the positions of a built VegVault database, read-only, assign each
#' to a stratum where links are hard to get right, and draw a reproducible
#' random sample of each stratum.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @param distance_km
#' Positive number. The link distance in km (`link: distance_km` in
#' `config.yml`).
#' @param n_per_stratum
#' Whole number, at least 1. The number of positions drawn per stratum; a
#' smaller stratum is taken whole.
#' @param seed
#' Whole number. The random seed of the draw, so that a rerun checks the
#' same positions.
#' @return
#' A tibble with one row per drawn position, sorted by stratum (in the
#' order below) and `position_id`: `position_id`, `coord_long`,
#' `coord_lat`, `age`, `stratum` and `n_stratum`, the number of positions
#' of the stratum in the database.
#' @details
#' The strata:
#' \itemize{
#'   \item `dateline`: positions within `distance_km` of the antimeridian,
#'     measured along their parallel, whose links can cross it;
#'   \item `high_latitude`: other positions where one degree of longitude
#'     is shorter than `distance_km` (above about 63.3 degrees for 50 km),
#'     so that links span more than one degree;
#'   \item `other`: every other position.
#' }
#' v1.0.0 missed links in the first two strata. Distances are geodesic on
#' the WGS84 ellipsoid (`geosphere::distGeo()`). The draw does not change
#' the random state of the session. Opens the database read-only. Aborts
#' when the database is not the one of the manifest.
#' @seealso [diagnose_link_distances()]
#' @examples
#' \dontrun{
#' select_link_positions(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest,
#'   distance_km = 50,
#'   n_per_stratum = 200L,
#'   seed = 900723L
#' )
#' }
select_link_positions <- function(
  path_database,
  list_build_manifest,
  distance_km,
  n_per_stratum,
  seed
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  assertthat::assert_that(
    base::is.numeric(distance_km),
    base::length(distance_km) == 1L,
    base::isTRUE(distance_km > 0),
    msg = "'distance_km' must be a positive number."
  )

  assertthat::assert_that(
    assertthat::is.count(n_per_stratum),
    msg = "'n_per_stratum' must be a whole number of at least 1."
  )

  assertthat::assert_that(
    base::is.numeric(seed),
    base::length(seed) == 1L,
    !base::is.na(seed),
    msg = "'seed' must be a number."
  )

  vec_strata <-
    c("dateline", "high_latitude", "other")

  data_positions <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT position_id, coord_long, coord_lat, age FROM Positions",
        "ORDER BY position_id"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(position_id = base::as.integer(position_id))

  if (
    base::nrow(data_positions) == 0L
  ) {
    res <-
      dplyr::mutate(
        data_positions,
        stratum = base::character(0),
        n_stratum = base::integer(0)
      )

    return(res)
  }

  # Distance to the antimeridian along the parallel, and the length of one
  #   degree of longitude, both geodesic and in km
  data_strata <-
    data_positions |>
    dplyr::mutate(
      km_to_dateline = geosphere::distGeo(
        p1 = base::cbind(coord_long, coord_lat),
        p2 = base::cbind(180, coord_lat)
      ) / 1e3,
      km_per_degree = geosphere::distGeo(
        p1 = base::cbind(0, coord_lat),
        p2 = base::cbind(1, coord_lat)
      ) / 1e3,
      stratum = dplyr::case_when(
        km_to_dateline <= distance_km ~ "dateline",
        km_per_degree < distance_km ~ "high_latitude",
        .default = "other"
      )
    ) |>
    dplyr::add_count(stratum, name = "n_stratum")

  data_drawn <-
    withr::with_seed(
      seed = seed,
      code = dplyr::slice_sample(
        data_strata,
        n = n_per_stratum,
        by = stratum
      )
    )

  res <-
    data_drawn |>
    dplyr::arrange(base::match(stratum, vec_strata), position_id) |>
    dplyr::select(
      position_id, coord_long, coord_lat, age, stratum, n_stratum
    )

  return(res)
}
