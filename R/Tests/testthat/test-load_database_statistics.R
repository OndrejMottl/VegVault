#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_database_statistics() counts the fixture", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  # The tables of the schema file; the one view of the schema is
  #   AbioticDataReference, whose columns are not counted
  n_tables_schema <-
    base::readLines(here::here("Data", "SQL", "make_tables.sql")) |>
    stringr::str_detect(pattern = "^CREATE TABLE") |>
    base::sum()

  n_columns_schema <-
    run_with_database(
      path_database = path_database,
      fn = function(con) {
        vec_tables <-
          base::setdiff(DBI::dbListTables(con), "AbioticDataReference")

        res_columns <-
          purrr::map_int(
            .x = vec_tables,
            .f = ~ base::length(DBI::dbListFields(con, .x))
          ) |>
          base::sum()

        return(res_columns)
      },
      flag_read_only = TRUE
    )

  res <-
    load_database_statistics(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(
    res,
    tibble::tibble(
      n_tables = base::as.double(n_tables_schema),
      n_views = 1,
      n_columns = base::as.double(n_columns_schema),
      size_bytes = base::as.double(base::file.size(path_database)),
      n_datasets = 9,
      n_samples = 11,
      n_samples_gridpoints = 3,
      n_taxa = 7,
      n_taxa_unclassified = 1,
      n_dataset_sources = 0,
      n_trait_domains = 2,
      n_trait_values = 3,
      n_abiotic_variables = 2,
      age_min = 0,
      age_max = 11000
    )
  )
})

testthat::test_that("load_database_statistics() leaves the file unchanged", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  md5_before <-
    tools::md5sum(path_database)

  res <-
    load_database_statistics(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(base::nrow(res), 1L)

  testthat::expect_equal(
    base::unname(tools::md5sum(path_database)),
    base::unname(md5_before)
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("load_database_statistics() counts tables and views", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res_before <-
    load_database_statistics(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  run_with_database(
    path_database = path_database,
    fn = function(con) {
      DBI::dbExecute(con, "CREATE TABLE Extra (a INTEGER, b TEXT)")

      DBI::dbExecute(con, "CREATE VIEW ExtraView AS SELECT a, b FROM Extra")
    },
    flag_read_only = FALSE
  )

  res_after <-
    load_database_statistics(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(
    dplyr::pull(res_after, n_tables),
    dplyr::pull(res_before, n_tables) + 1
  )

  testthat::expect_equal(dplyr::pull(res_after, n_views), 2)

  testthat::expect_equal(
    dplyr::pull(res_after, n_columns),
    dplyr::pull(res_before, n_columns) + 2
  )
})

testthat::test_that("load_database_statistics() counts empty classes", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  run_with_database(
    path_database = path_database,
    fn = function(con) {
      DBI::dbExecute(
        con,
        "INSERT INTO Taxa (taxon_id, taxon_name) VALUES (8, 'Unknown')"
      )

      DBI::dbExecute(
        con,
        stringr::str_c(
          "INSERT INTO TaxonClassification (taxon_id, taxon_species, ",
          "taxon_genus, taxon_family) VALUES (8, NULL, NULL, NULL)"
        )
      )
    },
    flag_read_only = FALSE
  )

  res <-
    load_database_statistics(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(dplyr::pull(res, n_taxa), 8)

  testthat::expect_equal(dplyr::pull(res, n_taxa_unclassified), 2)
})

testthat::test_that("load_database_statistics() counts dataset sources", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = stringr::str_c(
      "INSERT INTO DatasetSourcesID (data_source_id, data_source_desc) ",
      "VALUES (1, 'Source A'), (2, 'Source B')"
    ),
    flag_read_only = FALSE
  )

  res <-
    load_database_statistics(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(dplyr::pull(res, n_dataset_sources), 2)
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("load_database_statistics() keeps negative ages", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = "UPDATE Samples SET age = -75 WHERE sample_id = 7",
    flag_read_only = FALSE
  )

  res <-
    load_database_statistics(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(dplyr::pull(res, age_min), -75)

  testthat::expect_equal(dplyr::pull(res, age_max), 11000)
})

testthat::test_that("load_database_statistics() gives NA without ages", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  run_with_database(
    path_database = path_database,
    fn = DBI::dbExecute,
    statement = "UPDATE Samples SET age = NULL",
    flag_read_only = FALSE
  )

  res <-
    load_database_statistics(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_equal(dplyr::pull(res, age_min), NA_real_)

  testthat::expect_equal(dplyr::pull(res, age_max), NA_real_)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_database_statistics() refuses another database", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  testthat::expect_error(
    load_database_statistics(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "other.sqlite"))
    ),
    regexp = "build manifest"
  )
})

testthat::test_that("load_database_statistics() needs a path", {
  testthat::expect_error(
    load_database_statistics(
      path_database = NA_character_,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    ),
    regexp = "non-empty character scalar"
  )
})
