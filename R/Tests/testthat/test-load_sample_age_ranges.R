#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_sample_age_ranges() returns the age ranges", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_sample_age_ranges(
      path_database = path_database,
      dataset_name = "fossilpol_1001",
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(
    res,
    tibble::tibble(
      dataset_name = c("fossilpol_1001", "fossilpol_1001"),
      sample_id = c(7L, 8L),
      age = c(1000, 6000),
      age_iteration_min = c(900, 5800),
      age_iteration_max = c(1200, 6500)
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("load_sample_age_ranges() returns each sample once", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  # The schema rejects a repeated dataset-sample pair, which v1.0.0 allowed
  testthat::expect_error(
    run_with_database(
      path_database = path_database,
      fn = DBI::dbExecute,
      statement = "INSERT INTO DatasetSample VALUES (7, 7)",
      flag_read_only = FALSE
    ),
    regexp = "UNIQUE constraint failed: DatasetSample"
  )

  res <-
    load_sample_age_ranges(
      path_database = path_database,
      dataset_name = "fossilpol_1001",
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(dplyr::pull(res, sample_id), c(7L, 8L))
})

testthat::test_that("load_sample_age_ranges() needs a chosen dataset", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  list_manifest <-
    list(database = list(file_name = "f.sqlite"))

  testthat::expect_error(
    load_sample_age_ranges(
      path_database = path_database,
      dataset_name = NULL,
      list_build_manifest = list_manifest
    ),
    regexp = "sample_age: dataset_name"
  )

  testthat::expect_error(
    load_sample_age_ranges(
      path_database = path_database,
      dataset_name = "fossilpol_9999",
      list_build_manifest = list_manifest
    ),
    regexp = "No dataset"
  )

  testthat::expect_error(
    load_sample_age_ranges(
      path_database = path_database,
      dataset_name = "splot_cz_1",
      list_build_manifest = list_manifest
    ),
    regexp = "no age iterations"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_sample_age_ranges() validates its arguments", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  testthat::expect_error(
    load_sample_age_ranges(
      path_database = path_database,
      dataset_name = c("fossilpol_1001", "fossilpol_1002"),
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    ),
    regexp = "dataset_name"
  )

  testthat::expect_error(
    load_sample_age_ranges(
      path_database = path_database,
      dataset_name = "fossilpol_1001",
      list_build_manifest = list(database = list(file_name = "other.sqlite"))
    ),
    regexp = "build manifest"
  )
})
