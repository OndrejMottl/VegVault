#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_orphan_statements() returns the eight scopes", {
  res <-
    build_orphan_statements()

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c("scope", "status_found", "statement", "description")
  )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c(
      "datasets_without_samples", "samples_without_dataset",
      "positions_without_samples", "gridpoints_with_position",
      "links_to_other_samples", "linked_gridpoints_without_values",
      "taxa_without_use", "abiotic_variables_without_values"
    )
  )

  testthat::expect_equal(
    dplyr::pull(res, status_found),
    c(base::rep("fail", 5L), base::rep("flag", 3L))
  )

  testthat::expect_type(dplyr::pull(res, statement), "character")

  testthat::expect_false(base::anyNA(dplyr::pull(res, statement)))

  testthat::expect_type(dplyr::pull(res, description), "character")
})

#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_orphan_statements() statements count the rows", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  con <-
    DBI::dbConnect(
      drv = RSQLite::SQLite(),
      dbname = purrr::chuck(list_build, "path_database"),
      flags = RSQLite::SQLITE_RO
    )

  withr::defer(DBI::dbDisconnect(conn = con))

  list_results <-
    purrr::map(
      .x = dplyr::pull(build_orphan_statements(), statement),
      .f = ~ DBI::dbGetQuery(conn = con, statement = .x)
    )

  testthat::expect_equal(
    purrr::map_int(.x = list_results, .f = base::nrow),
    base::rep(1L, 8L)
  )

  testthat::expect_equal(
    purrr::map_int(.x = list_results, .f = base::ncol),
    base::rep(1L, 8L)
  )

  # Taxon 7 (Indet.) of the fixture is used by no sample, trait value or
  #   classification; every other scope finds nothing
  testthat::expect_equal(
    purrr::map_dbl(.x = list_results, .f = ~ base::as.numeric(.x[[1L]])),
    c(base::rep(0, 6L), 1, 0)
  )
})

testthat::test_that("build_orphan_statements() reads PositionLink once", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  con <-
    DBI::dbConnect(
      drv = RSQLite::SQLite(),
      dbname = purrr::chuck(list_build, "path_database")
    )

  withr::defer(DBI::dbDisconnect(conn = con))

  # Planner statistics (sqlite_stat1) of the tables these statements read,
  #   from the full-size 2.0.0 development database built on 2026-11-24,
  #   so that SQLite plans the statements as it does on that database
  data_stat_full <-
    tibble::tribble(
      ~tbl, ~idx, ~stat,
      "AbioticData", "AbioticData", "11063784 8 1",
      "AbioticData", "idx_abioticdata_abiotic_variable_id",
      "11063784 1382973",
      "AbioticVariable", NA_character_, "8",
      "DatasetSample", "DatasetSample", "12459714 30 1",
      "DatasetSample", "idx_datasetsample_sample_id", "12459714 1",
      "DatasetTypeID", NA_character_, "4",
      "Datasets", "idx_datasets_coord_long_lat", "421604 2 1",
      "Datasets", "idx_datasets_data_source_id", "421604 608",
      "Datasets", "idx_datasets_data_source_type_id", "421604 84321",
      "Datasets", "idx_datasets_dataset_id", "421604 1",
      "Datasets", "idx_datasets_dataset_type_id", "421604 105401",
      "Datasets", "idx_datasets_sampling_method_id", "421604 6801",
      "Datasets", "sqlite_autoindex_Datasets_1", "421604 1",
      "PositionLink", "PositionLink", "99774719 260 1",
      "Positions", "sqlite_autoindex_Positions_1", "384631 2 2 1",
      "SamplePosition", NA_character_, "9632976",
      "SampleTaxa", "SampleTaxa", "3398231 18 1",
      "SampleTaxa", "idx_sampletaxa_taxon_id", "3398231 72",
      "Samples", "idx_samples_sample_id", "12459714 1",
      "Samples", "idx_samples_sample_size_id", "12459714 24970",
      "Samples", "sqlite_autoindex_Samples_1", "12459714 1",
      "Taxa", NA_character_, "109221",
      "TaxonClassification", "idx_taxonclassification_taxon_family",
      "108356 209",
      "TaxonClassification", "idx_taxonclassification_taxon_genus",
      "108356 12",
      "TaxonClassification", "idx_taxonclassification_taxon_species",
      "108356 2",
      "TraitsValue", "TraitsValue", "10920952 50 1 1 1",
      "TraitsValue", "idx_traitsvalue_sample_id", "10920952 1",
      "TraitsValue", "idx_traitsvalue_taxon_id", "10920952 154",
      "TraitsValue", "idx_traitsvalue_trait_derivation_id",
      "10920952 5460476",
      "TraitsValue", "idx_traitsvalue_trait_id", "10920952 682560",
      "TraitsValue", "idx_traitsvalue_trait_unit_conversion_id",
      "10920952 173349"
    )

  # ANALYZE creates sqlite_stat1; its rows are then replaced, and
  #   ANALYZE sqlite_schema makes the planner reload them
  DBI::dbExecute(conn = con, statement = "ANALYZE")

  DBI::dbExecute(conn = con, statement = "DELETE FROM sqlite_stat1")

  DBI::dbAppendTable(conn = con, name = "sqlite_stat1", value = data_stat_full)

  DBI::dbExecute(conn = con, statement = "ANALYZE sqlite_schema")

  list_plans <-
    purrr::map(
      .x = dplyr::pull(build_orphan_statements(), statement),
      .f = ~ DBI::dbGetQuery(
        conn = con,
        statement = base::paste("EXPLAIN QUERY PLAN", .x)
      ) |>
        dplyr::pull(detail)
    )

  vec_plan_lines <-
    base::unlist(list_plans)

  # No skip-scan, which searches a key once per value of its first column
  testthat::expect_false(
    base::any(stringr::str_detect(string = vec_plan_lines, pattern = "ANY\\("))
  )

  testthat::expect_false(
    base::any(
      stringr::str_detect(
        string = vec_plan_lines,
        pattern = "SEARCH PositionLink"
      )
    )
  )

  testthat::expect_true(
    base::all(
      purrr::map_int(
        .x = list_plans,
        .f = ~ base::sum(
          stringr::str_detect(string = .x, pattern = "SCAN PositionLink")
        )
      ) <= 1L
    )
  )
})
