#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_gridpoint_locations() returns the gridpoints", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_gridpoint_locations(
      path_database = path_database,
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(
    res,
    tibble::tibble(
      coord_long = c(14.1, 16.1, 18),
      coord_lat = c(50.1, 49.6, 49)
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("load_gridpoint_locations() includes the edges", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_gridpoint_locations(
      path_database = path_database,
      list_region = list(
        lon_min = 14.1, lon_max = 16.1, lat_min = 49.6, lat_max = 50.1
      ),
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(dplyr::pull(res, coord_long), c(14.1, 16.1))
})

testthat::test_that("load_gridpoint_locations() may return no rows", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_gridpoint_locations(
      path_database = path_database,
      list_region = list(
        lon_min = -10, lon_max = 0, lat_min = 0, lat_max = 10
      ),
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(base::nrow(res), 0L)

  testthat::expect_named(res, c("coord_long", "coord_lat"))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_gridpoint_locations() validates its arguments", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  testthat::expect_error(
    load_gridpoint_locations(
      path_database = path_database,
      list_region = list(lon_min = 12),
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    ),
    regexp = "lon_max"
  )

  testthat::expect_error(
    load_gridpoint_locations(
      path_database = path_database,
      list_region = list(
        lon_min = 12, lon_max = 18.9, lat_min = 48.5, lat_max = 51.1
      ),
      list_build_manifest = list(database = list(file_name = "other.sqlite"))
    ),
    regexp = "build manifest"
  )
})
