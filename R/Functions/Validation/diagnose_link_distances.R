#' @title Diagnose the links of sampled positions against the link rule
#' @description
#' Recompute, for a sample of positions of a built VegVault database and
#' read-only, the distance and age difference of every stored link, and
#' find the gridpoints of the database that the rule links to these
#' positions but that are not linked.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @param data_positions
#' A tibble of sampled positions, as returned by `select_link_positions()`.
#' @param distance_km
#' Positive number. The link distance in km (`link: distance_km`).
#' @param distance_years
#' Number, at least 0. The link age difference in years
#' (`link: distance_years`).
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `link_distances`, with one row per stratum: `dateline`,
#' `high_latitude` and `other`. A row fails when a stored link is not as
#' recomputed, lies beyond the rule, or is missing; the observed value is
#' the number of such links. The message gives the positions drawn, the
#' links checked and each count.
#' @details
#' A position and a gridpoint sample are linked when
#' `geosphere::distGeo(position, gridpoint) / 1e3 <= distance_km` and the
#' absolute difference of their ages is at most `distance_years`; the
#' stored values are both truncated to whole numbers, as
#' `compute_position_links()` does. The gridpoint coordinates are those of
#' its dataset. Only gridpoints present in the database can be found
#' missing; a gridpoint the build never created is not detected. Links to
#' samples that are not gridpoints are left to `diagnose_orphan_rows()`.
#' The gridpoint samples are read once; candidates for a missing link are
#' those within `distance_km / 110` degrees of latitude, since a degree of
#' latitude is longer than 110 km. Opens the database read-only. Aborts
#' when the database is not the one of the manifest.
#' @seealso [select_link_positions()], [diagnose_sample_positions()]
#' @examples
#' \dontrun{
#' diagnose_link_distances(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest,
#'   data_positions = data_link_positions,
#'   distance_km = 50,
#'   distance_years = 5000
#' )
#' }
diagnose_link_distances <- function(
  path_database,
  list_build_manifest,
  data_positions,
  distance_km,
  distance_years
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  vec_columns <-
    c(
      "position_id", "coord_long", "coord_lat", "age", "stratum",
      "n_stratum"
    )

  assertthat::assert_that(
    base::is.data.frame(data_positions),
    base::all(vec_columns %in% base::names(data_positions)),
    msg = "'data_positions' must be a table of select_link_positions()."
  )

  assertthat::assert_that(
    base::is.numeric(distance_km),
    base::length(distance_km) == 1L,
    base::isTRUE(distance_km > 0),
    base::is.numeric(distance_years),
    base::length(distance_years) == 1L,
    base::isTRUE(distance_years >= 0),
    msg = stringr::str_c(
      "'distance_km' must be a positive number and 'distance_years' a ",
      "number of at least 0."
    )
  )

  vec_strata <-
    c("dateline", "high_latitude", "other")

  data_gridpoints <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT s.sample_id, d.coord_long AS grid_long,",
        "d.coord_lat AS grid_lat, s.age AS grid_age",
        "FROM DatasetSample AS ds",
        "JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
        "JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id",
        "JOIN Samples AS s ON s.sample_id = ds.sample_id",
        "WHERE t.dataset_type = 'gridpoints'",
        "AND d.coord_long IS NOT NULL AND d.coord_lat IS NOT NULL",
        "AND s.age IS NOT NULL"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(sample_id = base::as.integer(sample_id))

  # The stored links of the drawn positions, through the primary key
  data_stored <-
    if (
      base::nrow(data_positions) == 0L
    ) {
      tibble::tibble(
        position_id = base::integer(0),
        sample_ref_id = base::integer(0),
        distance_in_km = base::integer(0),
        distance_in_years = base::integer(0)
      )
    } else {
      run_with_database(
        path_database = path_database,
        fn = DBI::dbGetQuery,
        statement = stringr::str_c(
          "SELECT position_id, sample_ref_id, distance_in_km,",
          " distance_in_years FROM PositionLink WHERE position_id IN (",
          stringr::str_c(
            base::sprintf(
              "%d",
              base::as.integer(dplyr::pull(data_positions, position_id))
            ),
            collapse = ", "
          ),
          ")"
        ),
        flag_read_only = TRUE
      ) |>
        tibble::as_tibble() |>
        dplyr::mutate(
          dplyr::across(.cols = dplyr::everything(), .fns = base::as.integer)
        )
    }

  data_pairs_stored <-
    data_stored |>
    dplyr::inner_join(
      dplyr::select(
        data_positions,
        position_id, coord_long, coord_lat, age, stratum
      ),
      by = dplyr::join_by(position_id)
    ) |>
    dplyr::inner_join(
      data_gridpoints,
      by = dplyr::join_by(sample_ref_id == sample_id)
    )

  # Candidates for a link: gridpoints within the latitude window (a degree
  #   of latitude is longer than 110 km) and within the age difference.
  #   `between()` is part of the join_by() syntax, so it is not namespaced
  value_lat_window <-
    distance_km / 110

  data_windows <-
    data_positions |>
    dplyr::transmute(
      position_id, coord_long, coord_lat, age, stratum,
      lat_lo = coord_lat - value_lat_window,
      lat_hi = coord_lat + value_lat_window,
      age_lo = age - distance_years,
      age_hi = age + distance_years
    )

  data_pairs_candidate <-
    data_gridpoints |>
    dplyr::inner_join(
      data_windows,
      by = dplyr::join_by(
        between(grid_lat, lat_lo, lat_hi),
        between(grid_age, age_lo, age_hi)
      )
    )

  # The distance of each pair as the link step computes it (position
  #   first, then the gridpoint)
  list_pairs <-
    base::list(
      stored = data_pairs_stored,
      candidate = data_pairs_candidate
    ) |>
    purrr::map(
      .f = ~ dplyr::mutate(
        .x,
        km_exact = if (
          dplyr::n() == 0L
        ) {
          base::numeric(0)
        } else {
          geosphere::distGeo(
            p1 = base::cbind(coord_long, coord_lat),
            p2 = base::cbind(grid_long, grid_lat)
          ) / 1e3
        },
        years_exact = base::abs(age - grid_age)
      )
    )

  data_checked <-
    purrr::chuck(list_pairs, "stored") |>
    dplyr::mutate(
      flag_differs = base::as.integer(km_exact) != distance_in_km |
        base::as.integer(years_exact) != distance_in_years,
      flag_beyond = km_exact > distance_km | years_exact > distance_years
    )

  data_missing <-
    purrr::chuck(list_pairs, "candidate") |>
    dplyr::filter(km_exact <= distance_km, years_exact <= distance_years) |>
    dplyr::anti_join(
      data_stored,
      by = dplyr::join_by(position_id, sample_id == sample_ref_id)
    )

  data_summary <-
    tibble::tibble(stratum = vec_strata) |>
    dplyr::left_join(
      data_positions |>
        dplyr::group_by(stratum) |>
        dplyr::summarise(
          n_drawn = dplyr::n(),
          n_stratum = dplyr::first(n_stratum),
          .groups = "drop"
        ),
      by = dplyr::join_by(stratum)
    ) |>
    dplyr::left_join(
      data_checked |>
        dplyr::group_by(stratum) |>
        dplyr::summarise(
          n_links = dplyr::n(),
          n_differs = base::sum(flag_differs),
          n_beyond = base::sum(flag_beyond),
          n_bad = base::sum(flag_differs | flag_beyond),
          .groups = "drop"
        ),
      by = dplyr::join_by(stratum)
    ) |>
    dplyr::left_join(
      dplyr::count(data_missing, stratum, name = "n_missing"),
      by = dplyr::join_by(stratum)
    ) |>
    dplyr::mutate(
      dplyr::across(
        .cols = c(
          n_drawn, n_stratum, n_links, n_differs, n_beyond, n_bad,
          n_missing
        ),
        .fns = ~ dplyr::coalesce(base::as.integer(.x), 0L)
      ),
      n_failed = n_bad + n_missing,
      message = dplyr::if_else(
        n_drawn == 0L,
        "No positions in this stratum.",
        stringr::str_c(
          "Positions drawn: ", n_drawn, " of ", n_stratum,
          "; stored links checked: ", n_links,
          dplyr::if_else(
            n_differs > 0L,
            stringr::str_c(
              "; distance or age not as recomputed: ", n_differs
            ),
            ""
          ),
          dplyr::if_else(
            n_beyond > 0L,
            stringr::str_c(
              "; beyond ", base::sprintf("%.7g", distance_km), " km or ",
              base::sprintf("%.7g", distance_years), " years: ", n_beyond
            ),
            ""
          ),
          dplyr::if_else(
            n_missing > 0L,
            stringr::str_c(
              "; missing: ", n_missing,
              " (gridpoints of the database within the rule, not linked)"
            ),
            ""
          ),
          "."
        )
      )
    )

  res <-
    build_check_result(
      check_id = "link_distances",
      scope = dplyr::pull(data_summary, stratum),
      status = dplyr::if_else(
        dplyr::pull(data_summary, n_failed) > 0L,
        "fail",
        "pass"
      ),
      observed = dplyr::pull(data_summary, n_failed),
      threshold = 0L,
      message = dplyr::pull(data_summary, message)
    )

  return(res)
}
