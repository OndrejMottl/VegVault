#----------------------------------------------------------#
# Setup -----
#----------------------------------------------------------#

# Two positions near the dateline (one of them also at a high latitude)
#   and two at high latitudes, north and south
add_stratum_positions <- function(path_database) {
  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = base::paste(
      "INSERT INTO Positions VALUES (201, 179.95, 10, 0),",
      "(202, -179.98, 70, 0), (203, 20, 70, 0), (204, 20, -65, 500)"
    )
  )
}


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("select_link_positions() returns the positions", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    select_link_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      distance_km = 50,
      n_per_stratum = 100L,
      seed = 900723L
    )

  testthat::expect_named(
    res,
    c(
      "position_id", "coord_long", "coord_lat", "age", "stratum",
      "n_stratum"
    )
  )

  testthat::expect_equal(
    dplyr::pull(res, position_id),
    c(1L, 2L, 101L, 102L, 103L, 104L, 105L)
  )

  testthat::expect_true(base::all(dplyr::pull(res, stratum) == "other"))

  testthat::expect_true(base::all(dplyr::pull(res, n_stratum) == 7L))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("select_link_positions() assigns the strata", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  add_stratum_positions(
    path_database = purrr::chuck(list_build, "path_database")
  )

  res <-
    select_link_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      distance_km = 50,
      n_per_stratum = 100L,
      seed = 900723L
    )

  testthat::expect_equal(
    dplyr::pull(res, stratum),
    c(
      "dateline", "dateline", "high_latitude", "high_latitude",
      base::rep("other", 7L)
    )
  )

  testthat::expect_equal(
    dplyr::pull(res, position_id)[1:4],
    c(201L, 202L, 203L, 204L)
  )

  testthat::expect_equal(
    dplyr::pull(res, n_stratum),
    c(2L, 2L, 2L, 2L, base::rep(7L, 7L))
  )
})

testthat::test_that("select_link_positions() draws reproducibly", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  add_stratum_positions(
    path_database = purrr::chuck(list_build, "path_database")
  )

  # The draw must leave the random state of the session as it was
  base::set.seed(1L)

  value_expected <-
    stats::runif(1L)

  base::set.seed(1L)

  res_first <-
    select_link_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      distance_km = 50,
      n_per_stratum = 1L,
      seed = 900723L
    )

  testthat::expect_equal(stats::runif(1L), value_expected)

  res_second <-
    select_link_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      distance_km = 50,
      n_per_stratum = 1L,
      seed = 900723L
    )

  testthat::expect_equal(res_first, res_second)

  testthat::expect_equal(
    dplyr::pull(res_first, stratum),
    c("dateline", "high_latitude", "other")
  )

  testthat::expect_equal(dplyr::pull(res_first, n_stratum), c(2L, 2L, 7L))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("select_link_positions() needs a positive sample", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    select_link_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      distance_km = 50,
      n_per_stratum = 0L,
      seed = 900723L
    ),
    regexp = "n_per_stratum"
  )
})

testthat::test_that("select_link_positions() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    select_link_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      ),
      distance_km = 50,
      n_per_stratum = 1L,
      seed = 900723L
    ),
    regexp = "not the database of the build manifest"
  )
})
