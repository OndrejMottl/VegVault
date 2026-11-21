#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("compute_database_counts() counts every metric", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    compute_database_counts(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(res, c("metric", "scope", "n_v2"))

  testthat::expect_equal(
    base::unique(dplyr::pull(res, metric)),
    c(
      "table_rows", "datasets", "samples", "positions", "sample_taxa_rows",
      "traits_value_rows", "abiotic_values", "sample_links"
    )
  )

  testthat::expect_type(dplyr::pull(res, n_v2), "double")

  # Tables only: the view AbioticDataReference is counted as sample_links
  vec_tables <-
    dplyr::pull(dplyr::filter(res, metric == "table_rows"), scope)

  testthat::expect_false("AbioticDataReference" %in% vec_tables)

  testthat::expect_true(
    base::all(c("Positions", "PositionLink", "BuildProducers") %in% vec_tables)
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("compute_database_counts() gives the fixture counts", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    compute_database_counts(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  data_expected <-
    tibble::tribble(
      ~metric, ~scope, ~n_v2,
      "table_rows", "Samples", 11,
      "table_rows", "Positions", 7,
      "table_rows", "PositionLink", 2,
      "datasets", "gridpoints / gridpoints", 3,
      "datasets", "vegetation_plot / sPlotOpen", 2,
      "samples", "fossil_pollen_archive / FOSSILPOL", 4,
      "samples", "traits / TRY", 1,
      "positions", "all", 7,
      "positions", "fossil_pollen_archive / FOSSILPOL", 4,
      "positions", "vegetation_plot / BIEN", 1,
      "sample_taxa_rows", "fossil_pollen_archive / FOSSILPOL", 6,
      "sample_taxa_rows", "vegetation_plot / sPlotOpen", 3,
      "traits_value_rows", "traits / TRY", 3,
      "abiotic_values", "bio1", 3,
      "abiotic_values", "bio12", 2,
      "sample_links", "all", 2
    )

  data_found <-
    dplyr::inner_join(
      res,
      dplyr::select(data_expected, metric, scope),
      by = dplyr::join_by(metric, scope)
    )

  testthat::expect_equal(
    dplyr::arrange(data_found, metric, scope),
    dplyr::arrange(data_expected, metric, scope)
  )

  # The trait sample has no position, so TRY has no positions row
  testthat::expect_false(
    "traits / TRY" %in%
      dplyr::pull(dplyr::filter(res, metric == "positions"), scope)
  )
})

testthat::test_that("compute_database_counts() multiplies shared positions", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # A second plot sample at position 1 gets its two links through the
  #   position: 2 samples times 1 link, plus 1 for position 2
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        "INSERT INTO Samples (sample_id, sample_name, age) VALUES (30, 'p', 0)"
      )
      DBI::dbExecute(.x, "INSERT INTO DatasetSample VALUES (1, 30)")
      DBI::dbExecute(.x, "INSERT INTO SamplePosition VALUES (30, 1)")
    }
  )

  res <-
    compute_database_counts(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(
    dplyr::pull(dplyr::filter(res, metric == "sample_links"), n_v2),
    3
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_database_counts() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    compute_database_counts(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
