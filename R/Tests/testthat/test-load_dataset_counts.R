#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_dataset_counts() counts the datasets", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_dataset_counts(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(
    res,
    tibble::tibble(
      dataset_type = c(
        "fossil_pollen_archive", "gridpoints", "traits",
        "vegetation_plot", "vegetation_plot"
      ),
      dataset_source_type = c(
        "FOSSILPOL", "gridpoints", "TRY", "BIEN", "sPlotOpen"
      ),
      n_datasets = c(2L, 3L, 1L, 1L, 2L)
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("load_dataset_counts() counts datasets without source", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = stringr::str_c(
      "INSERT INTO Datasets (dataset_id, dataset_name, dataset_type_id) ",
      "VALUES (10, 'trait_without_source', 3)"
    ),
    flag_read_only = FALSE
  )

  res <-
    load_dataset_counts(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(
    dplyr::filter(res, dataset_type == "traits"),
    tibble::tibble(
      dataset_type = c("traits", "traits"),
      dataset_source_type = c("TRY", NA),
      n_datasets = c(1L, 1L)
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_dataset_counts() refuses another database", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  testthat::expect_error(
    load_dataset_counts(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "other.sqlite"))
    ),
    regexp = "build manifest"
  )
})
