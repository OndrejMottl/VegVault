#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_v1_reference_counts() collects the counts", {
  res <-
    build_v1_reference_counts()

  testthat::expect_named(res, c("metric", "scope", "n_v1", "source"))

  testthat::expect_equal(
    base::unique(dplyr::pull(res, metric)),
    c(
      "table_rows", "datasets", "samples", "positions", "sample_taxa_rows",
      "traits_value_rows", "abiotic_values"
    )
  )

  testthat::expect_type(dplyr::pull(res, n_v1), "double")

  testthat::expect_false(base::anyNA(dplyr::pull(res, source)))

  testthat::expect_equal(
    base::nrow(dplyr::filter(res, metric == "table_rows")),
    29L
  )

  testthat::expect_false(
    base::anyDuplicated(dplyr::select(res, metric, scope)) > 0L
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_v1_reference_counts() keeps the v1 numbers", {
  res <-
    build_v1_reference_counts()

  # The exact counts of Documentation/Database_design_2.0.0.md, "Rows",
  #   and of R/Validation/count_v1_per_source.R
  data_expected <-
    tibble::tribble(
      ~metric, ~scope, ~n_v1,
      "table_rows", "AbioticDataReference", 2067445952,
      "table_rows", "SampleTaxa", 3689420,
      "datasets", "traits / TRY", 32342,
      "datasets", "gridpoints / gridpoints", 106447,
      "samples", "fossil_pollen_archive / FOSSILPOL", 88423,
      "samples", "traits / BIEN", 10399832,
      "positions", "all", 373225,
      "positions", "traits / BIEN", 194675,
      "sample_taxa_rows", "vegetation_plot / sPlotOpen", 1520208,
      "traits_value_rows", "traits / TRY", 1205168,
      "abiotic_values", "bio15", 1541019,
      "abiotic_values", "HWSD2", 73808
    )

  data_found <-
    dplyr::inner_join(
      dplyr::select(res, metric, scope, n_v1),
      dplyr::select(data_expected, metric, scope),
      by = dplyr::join_by(metric, scope)
    )

  testthat::expect_equal(
    dplyr::arrange(data_found, metric, scope),
    dplyr::arrange(data_expected, metric, scope)
  )
})

testthat::test_that("build_v1_reference_counts() names rows without ids", {
  path_scan <-
    base::file.path(withr::local_tempdir(), "scan.csv")

  readr::write_csv(
    tibble::tribble(
      ~metric, ~dataset_type_id, ~data_source_type_id, ~n_rows, ~seconds,
      "sample_taxa_rows", 1L, 1L, 10, 1,
      "sample_taxa_rows", NA, NA, 2, 1
    ),
    path_scan,
    na = ""
  )

  res <-
    build_v1_reference_counts(path_scan_per_source = path_scan)

  data_taxa <-
    dplyr::filter(res, metric == "sample_taxa_rows")

  testthat::expect_equal(
    dplyr::pull(data_taxa, scope),
    c("(none) / (none)", "vegetation_plot / sPlotOpen")
  )

  testthat::expect_equal(dplyr::pull(data_taxa, n_v1), c(2, 10))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_v1_reference_counts() needs every scan", {
  testthat::expect_error(
    build_v1_reference_counts(dir_scans = withr::local_tempdir()),
    regexp = "V1_"
  )
})
