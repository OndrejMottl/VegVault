#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("save_table_column_types() writes the file", {
  dir_export <-
    withr::local_tempdir()

  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  run_with_database(
    path_database = path_database,
    fn = DBI::dbWriteTable,
    name = "Datasets",
    value = base::data.frame(dataset_id = 1:2, dataset_name = c("a", "b"))
  )

  data_column_types <-
    load_table_column_types(
      path_database = path_database,
      table_name = "Datasets",
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      )
    )

  res <-
    save_table_column_types(
      data_column_types = data_column_types,
      dir_export = dir_export
    )

  path_csv <-
    base::file.path(dir_export, "Column_names", "Datasets_columns.csv")

  testthat::expect_type(res, "character")

  testthat::expect_equal(res, path_csv)

  testthat::expect_equal(
    base::readLines(con = path_csv),
    c(
      "column_name,data_type",
      "dataset_id,integer",
      "dataset_name,character"
    )
  )
})

testthat::test_that("save_table_column_types() replaces an existing file", {
  dir_export <-
    withr::local_tempdir()

  base::dir.create(base::file.path(dir_export, "Column_names"))

  path_csv <-
    base::file.path(dir_export, "Column_names", "Datasets_columns.csv")

  base::writeLines(text = "old content", con = path_csv)

  res <-
    save_table_column_types(
      data_column_types = tibble::tibble(
        table_name = "Datasets",
        column_name = "dataset_id",
        data_type = "integer"
      ),
      dir_export = dir_export
    )

  testthat::expect_equal(res, path_csv)

  testthat::expect_equal(
    base::readLines(con = path_csv),
    c("column_name,data_type", "dataset_id,integer")
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_table_column_types() needs one table", {
  dir_export <-
    withr::local_tempdir()

  testthat::expect_error(
    save_table_column_types(
      data_column_types = tibble::tibble(
        table_name = c("Datasets", "Samples"),
        column_name = c("dataset_id", "sample_id"),
        data_type = c("integer", "integer")
      ),
      dir_export = dir_export
    ),
    regexp = "one table"
  )

  testthat::expect_error(
    save_table_column_types(
      data_column_types = tibble::tibble(
        table_name = base::character(0),
        column_name = base::character(0),
        data_type = base::character(0)
      ),
      dir_export = dir_export
    ),
    regexp = "one table"
  )

  testthat::expect_error(
    save_table_column_types(
      data_column_types = tibble::tibble(column_name = "a"),
      dir_export = dir_export
    ),
    regexp = "data_column_types"
  )
})
