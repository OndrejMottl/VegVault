#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_missing_coordinates() passes the fixture", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_missing_coordinates(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_true(
    base::all(dplyr::pull(res, check_id) == "missing_coordinates")
  )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "fossil_pollen_archive / FOSSILPOL", "gridpoints / gridpoints",
      "traits / TRY", "vegetation_plot / BIEN", "vegetation_plot / sPlotOpen"
    )
  )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "pass"))

  testthat::expect_equal(
    dplyr::pull(res, threshold),
    c("2", "3", "1", "1", "2")
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_missing_coordinates() flags each group", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # Two TRY datasets without a longitude, and one dataset without a type,
  #   a source or coordinates
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        "UPDATE Datasets SET coord_long = NULL WHERE dataset_id = 9"
      )
      DBI::dbExecute(
        .x,
        base::paste(
          "INSERT INTO Datasets (dataset_id, dataset_name, dataset_type_id,",
          "data_source_type_id, coord_lat) VALUES (10, 'try_la_2', 3, 4, -15)"
        )
      )
      DBI::dbExecute(
        .x,
        "INSERT INTO Datasets (dataset_id, dataset_name) VALUES (11, 'x')"
      )
    }
  )

  res <-
    diagnose_missing_coordinates(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  data_flagged <-
    dplyr::filter(res, status == "flag")

  testthat::expect_equal(
    dplyr::pull(data_flagged, scope),
    c("(none) / (none)", "traits / TRY")
  )

  testthat::expect_equal(dplyr::pull(data_flagged, observed), c("1", "2"))

  testthat::expect_equal(dplyr::pull(data_flagged, threshold), c("1", "2"))

  testthat::expect_equal(base::nrow(res), 6L)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_missing_coordinates() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_missing_coordinates(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
