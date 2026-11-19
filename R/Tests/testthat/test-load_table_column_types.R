#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_table_column_types() reads names and types", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(
      dataset_id = 1:2,
      dataset_name = c("a", "b"),
      coord_long = c(10.5, -3.25)
    )
  )

  res <-
    load_table_column_types(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      )
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(res, c("table_name", "column_name", "data_type"))

  testthat::expect_equal(
    dplyr::pull(res, table_name),
    base::rep("Datasets", 3L)
  )

  testthat::expect_equal(
    dplyr::pull(res, column_name),
    c("dataset_id", "dataset_name", "coord_long")
  )

  testthat::expect_equal(
    dplyr::pull(res, data_type),
    c("integer", "character", "numeric")
  )
})

testthat::test_that("load_table_column_types() reads an empty table", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = "CREATE TABLE Empty (empty_id INTEGER, label TEXT)"
  )

  res <-
    load_table_column_types(
      path_database = path_database,
      table_name = "Empty",
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      )
    )

  testthat::expect_equal(
    dplyr::pull(res, data_type),
    c("integer", "character")
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("load_table_column_types() checks the table name", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(dataset_id = 1L)
  )

  list_manifest <-
    list(database = list(file_name = "VegVault.sqlite"))

  testthat::expect_error(
    load_table_column_types(
      path_database = path_database,
      table_name = "Datasets; DROP TABLE Datasets",
      list_build_manifest = list_manifest
    ),
    regexp = "table_name"
  )

  testthat::expect_error(
    load_table_column_types(
      path_database = path_database,
      table_name = "Missing",
      list_build_manifest = list_manifest
    ),
    regexp = "no such table"
  )

  testthat::expect_error(
    load_table_column_types(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list(
        database = list(file_name = "VegVault_other.sqlite")
      )
    ),
    regexp = "manifest"
  )
})
