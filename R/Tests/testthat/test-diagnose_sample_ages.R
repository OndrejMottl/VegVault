#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_sample_ages() reports each source", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_sample_ages(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      vec_gridpoint_ages = base::seq(from = 0, to = 18000, by = 500)
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "fossil_pollen_archive / FOSSILPOL", "gridpoints / gridpoints",
      "traits / TRY", "vegetation_plot / BIEN", "vegetation_plot / sPlotOpen"
    )
  )

  testthat::expect_true(base::all(dplyr::pull(res, check_id) == "sample_ages"))

  # The fixture's trait sample has no age
  testthat::expect_equal(
    dplyr::pull(res, status),
    c("pass", "pass", "flag", "pass", "pass")
  )

  testthat::expect_equal(
    dplyr::pull(res, observed),
    c("0", "0", "1", "0", "0")
  )

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[1], "^4 samples, ages 1000 to 11000")

  testthat::expect_match(vec_messages[3], "missing: 1")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_sample_ages() flags impossible ages", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # A fossil sample of 2050 CE, after the build of 2026 (age below -76),
  #   one of 1980 CE, and a gridpoint between two time steps
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO Samples (sample_id, sample_name, age) VALUES",
          "(20, 'fossil_future', -100), (21, 'fossil_recent', -30),",
          "(22, 'grid_between', 250)"
        )
      )
      DBI::dbExecute(
        .x,
        "INSERT INTO DatasetSample VALUES (7, 20), (7, 21), (3, 22)"
      )
    }
  )

  res <-
    diagnose_sample_ages(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      vec_gridpoint_ages = base::seq(from = 0, to = 18000, by = 500)
    )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c("flag", "flag", "flag", "pass", "pass")
  )

  testthat::expect_equal(
    dplyr::pull(res, observed),
    c("1", "1", "1", "0", "0")
  )

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[1], "after the build \\(below -76\\): 1")

  testthat::expect_match(vec_messages[2], "off the climate time steps: 1")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_sample_ages() needs the build year", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  list_build_manifest <-
    purrr::assign_in(
      purrr::chuck(list_build, "list_build_manifest"),
      where = "build_time_utc",
      value = "unknown"
    )

  testthat::expect_error(
    diagnose_sample_ages(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = list_build_manifest,
      vec_gridpoint_ages = base::seq(from = 0, to = 18000, by = 500)
    ),
    regexp = "build_time_utc"
  )
})

testthat::test_that("diagnose_sample_ages() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_sample_ages(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      ),
      vec_gridpoint_ages = 0
    ),
    regexp = "not the database of the build manifest"
  )
})
