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

testthat::test_that("load_database_table_names() leaves out views", {
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
    fn = DBI::dbExecute,
    statement = "CREATE VIEW SampleIds AS SELECT sample_id FROM Samples"
  )

  res <-
    load_database_table_names(
      path_database = path_database,
      list_build_manifest = list(
        database = list(file_name = "VegVault.sqlite")
      )
    )

  testthat::expect_equal(res, "Samples")
})

testthat::test_that("load_database_table_names() exports position tables", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_database_table_names(
      path_database = path_database,
      list_build_manifest = list(
        database = list(file_name = "f.sqlite")
      )
    )

  # The links are exported as the three position tables; the view that
  #   joins them to one row per sample and gridpoint is not
  testthat::expect_true(
    base::all(c("Positions", "SamplePosition", "PositionLink") %in% res)
  )

  testthat::expect_false("AbioticDataReference" %in% res)
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
