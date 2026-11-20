#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_db_table_data_types() lists columns and types", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    run_with_database(
      path_database = path_database,
      fn = load_db_table_data_types,
      table_name = "SampleSizeID",
      flag_read_only = TRUE
    )

  testthat::expect_true(base::is.data.frame(res))

  testthat::expect_equal(
    base::as.data.frame(res),
    base::data.frame(
      column_name = c("sample_size_id", "sample_size", "description"),
      data_type = c("INTEGER", "REAL", "TEXT")
    )
  )
})
