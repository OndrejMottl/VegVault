#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_database_fixture() writes a SQLite file", {
  path_database <-
    base::file.path(withr::local_tempdir(), "fixture.sqlite")

  res <-
    build_database_fixture(path_database = path_database)

  testthat::expect_equal(res, path_database)

  testthat::expect_true(base::file.exists(path_database))

  vec_header <-
    base::readBin(path_database, what = "raw", n = 15L)

  testthat::expect_equal(base::rawToChar(vec_header), "SQLite format 3")
})

testthat::test_that("build_database_fixture() fills the documented rows", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  vec_tables <-
    c(
      "Datasets", "Samples", "DatasetSample", "SampleUncertainty",
      "SampleSizeID", "Taxa", "TaxonClassification", "SampleTaxa",
      "AbioticVariable", "AbioticData", "AbioticDataReference",
      "TraitsDomain", "Traits", "TraitsValue", "TraitUnitConversion",
      "DatasetTypeID", "DatasetSourceTypeID", "References"
    )

  vec_n_rows <-
    run_with_database(
      path_database = path_database,
      fn = function(con) {
        res <-
          purrr::map_int(
            .x = vec_tables,
            .f = ~ DBI::dbGetQuery(
              conn = con,
              statement = stringr::str_c("SELECT COUNT(*) FROM [", .x, "]")
            )[[1]]
          )

        return(res)
      },
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    vec_n_rows,
    c(9L, 11L, 11L, 10L, 2L, 7L, 6L, 10L, 2L, 5L, 2L, 2L, 2L, 3L, 1L,
      4L, 5L, 0L)
  )
})

testthat::test_that("build_database_fixture() numbers gridpoints as 4", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  data_types <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT dataset_type_id, dataset_type FROM DatasetTypeID ",
        "ORDER BY dataset_type_id"
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    dplyr::pull(data_types, dataset_type),
    c("vegetation_plot", "fossil_pollen_archive", "traits", "gridpoints")
  )

  data_names <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT dataset_name FROM Datasets WHERE dataset_id = 7",
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    dplyr::pull(data_names, dataset_name),
    "fossilpol_1001"
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("build_database_fixture() never overwrites a file", {
  path_database <-
    base::file.path(withr::local_tempdir(), "existing.sqlite")

  base::writeLines(text = "keep", con = path_database)

  testthat::expect_error(
    build_database_fixture(path_database = path_database),
    regexp = "exists"
  )

  testthat::expect_equal(base::readLines(path_database), "keep")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_database_fixture() validates arguments", {
  testthat::expect_error(
    build_database_fixture(path_database = 1),
    regexp = "path_database"
  )

  testthat::expect_error(
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite"),
      path_schema = base::file.path(withr::local_tempdir(), "missing.sql")
    ),
    regexp = "path_schema"
  )
})
