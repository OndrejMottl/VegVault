#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_link_distances() passes correct links", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  data_positions <-
    select_link_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      distance_km = 50,
      n_per_stratum = 100L,
      seed = 900723L
    )

  res <-
    diagnose_link_distances(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_positions = data_positions,
      distance_km = 50,
      distance_years = 5000
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c("dateline", "high_latitude", "other")
  )

  testthat::expect_true(
    base::all(dplyr::pull(res, check_id) == "link_distances")
  )

  testthat::expect_equal(dplyr::pull(res, status), c("pass", "pass", "pass"))

  testthat::expect_equal(dplyr::pull(res, observed), c("0", "0", "0"))

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[1], "^No positions")

  testthat::expect_match(
    vec_messages[3],
    "^Positions drawn: 7 of 7; stored links checked: 2"
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_link_distances() fails wrong links", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  path_database <-
    purrr::chuck(list_build, "path_database")

  # A dateline position linked correctly to a gridpoint across the
  #   antimeridian, with the distance the link step stores
  distance_dateline <-
    base::as.integer(
      geosphere::distGeo(p1 = c(179.95, 65.02), p2 = c(-179.95, 65.05)) / 1e3
    )

  run_with_database(
    path_database = path_database,
    fn = ~ {
      # Other: the stored distance of link 1 to 3 is wrong; position 2 is
      #   linked to gridpoint 5, 156 km away; a new gridpoint 6.6 km from
      #   position 2 is not linked at age 0, and is not due at 6000 years
      DBI::dbExecute(
        .x,
        base::paste(
          "UPDATE PositionLink SET distance_in_km = 10",
          "WHERE position_id = 1 AND sample_ref_id = 3"
        )
      )
      DBI::dbExecute(.x, "INSERT INTO PositionLink VALUES (2, 5, 49, 0)")
      # Dateline: one gridpoint linked across the antimeridian, one missing
      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO Datasets (dataset_id, dataset_name, dataset_type_id,",
          "data_source_type_id, coord_long, coord_lat) VALUES",
          "(50, 'grid_test_50', 4, 5, 16.05, 49.55),",
          "(60, 'grid_test_60', 4, 5, -179.95, 65.05),",
          "(61, 'grid_test_61', 4, 5, -179.9, 65)"
        )
      )
      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO Samples (sample_id, sample_name, age) VALUES",
          "(50, 'grid_test_50', 0), (51, 'grid_test_51', 6000),",
          "(60, 'grid_test_60', 0), (61, 'grid_test_61', 0)"
        )
      )
      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO DatasetSample VALUES (50, 50), (50, 51), (60, 60),",
          "(61, 61)"
        )
      )
      DBI::dbExecute(
        .x,
        "INSERT INTO Positions VALUES (201, 179.95, 65.02, 0)"
      )
      DBI::dbExecute(
        .x,
        "INSERT INTO PositionLink VALUES (201, 60, ?, 0)",
        params = base::list(distance_dateline)
      )
    }
  )

  data_positions <-
    select_link_positions(
      path_database = path_database,
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      distance_km = 50,
      n_per_stratum = 100L,
      seed = 900723L
    )

  res <-
    diagnose_link_distances(
      path_database = path_database,
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_positions = data_positions,
      distance_km = 50,
      distance_years = 5000
    )

  testthat::expect_equal(dplyr::pull(res, status), c("fail", "pass", "fail"))

  testthat::expect_equal(dplyr::pull(res, observed), c("1", "0", "3"))

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[1], "stored links checked: 1")

  testthat::expect_match(vec_messages[1], "missing: 1")

  testthat::expect_match(vec_messages[3], "not as recomputed: 2")

  testthat::expect_match(vec_messages[3], "beyond 50 km or 5000 years: 1")

  testthat::expect_match(vec_messages[3], "missing: 1")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_link_distances() needs sampled positions", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_link_distances(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      data_positions = tibble::tibble(position_id = 1L),
      distance_km = 50,
      distance_years = 5000
    ),
    regexp = "data_positions"
  )
})

testthat::test_that("diagnose_link_distances() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_link_distances(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      ),
      data_positions = tibble::tibble(),
      distance_km = 50,
      distance_years = 5000
    ),
    regexp = "not the database of the build manifest"
  )
})
