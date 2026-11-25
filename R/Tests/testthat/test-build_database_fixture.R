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
      "DatasetTypeID", "DatasetSourceTypeID", "References",
      "Positions", "SamplePosition", "PositionLink", "version_control"
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
    c(9L, 11L, 11L, 10L, 2L, 7L, 6L, 10L, 2L, 5L, 2L, 2L, 2L, 3L, 2L,
      4L, 5L, 0L, 2L, 2L, 2L, 1L)
  )
})

testthat::test_that("build_database_fixture() records version 2.0.0", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  data_versions <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT id, version FROM version_control",
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    data_versions,
    base::data.frame(id = 1L, version = "2.0.0")
  )
})

testthat::test_that("build_database_fixture() links plots 1 and 2", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  data_links <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "SELECT * FROM AbioticDataReference ORDER BY sample_id",
      flag_read_only = TRUE
    )

  testthat::expect_equal(
    data_links,
    base::data.frame(
      sample_id = c(1L, 2L),
      sample_ref_id = c(3L, 4L),
      distance_in_km = c(10L, 12L),
      distance_in_years = c(0L, 0L)
    )
  )
})

testthat::test_that("build_database_fixture() has the project schema", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    run_with_database(
      path_database = path_database,
      fn = validate_database_schema,
      flag_read_only = TRUE
    )

  testthat::expect_equal(base::nrow(res), 64L)

  list_checks <-
    run_with_database(
      path_database = path_database,
      fn = ~ list(
        foreign_keys = DBI::dbGetQuery(
          conn = .x,
          statement = "PRAGMA foreign_key_check"
        ),
        integrity = DBI::dbGetQuery(
          conn = .x,
          statement = "PRAGMA integrity_check"
        )
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(base::nrow(list_checks[["foreign_keys"]]), 0L)

  testthat::expect_equal(dplyr::pull(list_checks[["integrity"]], 1), "ok")
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

testthat::test_that("build_database_fixture() gives values their unit", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  # Each trait value must be in the unit its rule produces, as the
  #   validation stage checks: the trait unit of its domain equals the
  #   standardized unit of its conversion rule (no derivation here)
  data_units <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = stringr::str_c(
        "SELECT tv.trait_id, td.trait_unit, uc.conversion_rule_key, ",
        "uc.standardized_unit FROM TraitsValue AS tv ",
        "JOIN Traits AS tr ON tr.trait_id = tv.trait_id ",
        "JOIN TraitsDomain AS td ON td.trait_domain_id = tr.trait_domain_id ",
        "JOIN TraitUnitConversion AS uc ",
        "ON uc.trait_unit_conversion_id = tv.trait_unit_conversion_id ",
        "ORDER BY tv.trait_id, tv.taxon_id"
      ),
      flag_read_only = TRUE
    )

  testthat::expect_equal(base::nrow(data_units), 3L)

  testthat::expect_equal(
    dplyr::pull(data_units, trait_unit),
    dplyr::pull(data_units, standardized_unit)
  )

  testthat::expect_equal(
    dplyr::pull(data_units, conversion_rule_key),
    c("fixture_identity", "fixture_identity", "fixture_identity_mm2")
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
