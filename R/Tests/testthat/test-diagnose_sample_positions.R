#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_sample_positions() reports each source", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_sample_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  # Gridpoints are not placed, so they have no row
  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "fossil_pollen_archive / FOSSILPOL", "traits / TRY",
      "vegetation_plot / BIEN", "vegetation_plot / sPlotOpen"
    )
  )

  testthat::expect_true(
    base::all(dplyr::pull(res, check_id) == "sample_positions")
  )

  # The fossil and BIEN positions have no gridpoint within reach
  testthat::expect_equal(
    dplyr::pull(res, status),
    c("flag", "pass", "flag", "pass")
  )

  testthat::expect_equal(dplyr::pull(res, observed), c("4", "0", "1", "0"))

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(
    vec_messages[1],
    "^4 samples; position without a link: 4"
  )

  testthat::expect_match(vec_messages[2], "without coordinates or age: 1")

  testthat::expect_equal(vec_messages[4], "2 samples.")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_sample_positions() fails wrong positions", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # Plot sample 1 loses its position; the BIEN plot's position gets
  #   another age
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(.x, "DELETE FROM SamplePosition WHERE sample_id = 1")
      DBI::dbExecute(
        .x,
        "UPDATE Positions SET age = 500 WHERE position_id = 101"
      )
    }
  )

  res <-
    diagnose_sample_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(
    dplyr::pull(res, status),
    c("flag", "pass", "fail", "fail")
  )

  testthat::expect_equal(dplyr::pull(res, observed), c("4", "0", "1", "1"))

  vec_messages <-
    dplyr::pull(res, message)

  testthat::expect_match(vec_messages[3], "position differs.*: 1")

  testthat::expect_match(
    vec_messages[4],
    "with coordinates and age but no position: 1"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_sample_positions() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_sample_positions(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
