#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_database_table_names() lists sorted tables", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Samples",
    value = base::data.frame(sample_id = 1:2)
  )

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(dataset_id = 1L)
  )

  res <-
    load_database_table_names(
      path_database = path_database,
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      )
    )

  testthat::expect_type(res, "character")

  testthat::expect_equal(res, c("Datasets", "Samples"))
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("load_database_table_names() needs its manifest", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(dataset_id = 1L)
  )

  testthat::expect_error(
    load_database_table_names(
      path_database = path_database,
      list_build_manifest = list(
        database = list(file_name = "VegVault_other.sqlite")
      )
    ),
    regexp = "manifest"
  )
})

testthat::test_that("load_database_table_names() never creates the file", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  testthat::expect_error(
    load_database_table_names(
      path_database = path_database,
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      )
    ),
    regexp = "does not exist"
  )

  testthat::expect_false(base::file.exists(path_database))
})
