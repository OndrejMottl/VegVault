#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_dataset_counts() labels and orders counts", {
  data_counts <-
    tibble::tibble(
      dataset_type = c(
        "fossil_pollen_archive", "gridpoints", "traits",
        "vegetation_plot", "vegetation_plot"
      ),
      dataset_source_type = c(
        "FOSSILPOL", "gridpoints", "TRY", "BIEN", "sPlotOpen"
      ),
      n_datasets = c(4000L, 120000L, 30000L, 60000L, 90000L)
    )

  res <-
    prepare_dataset_counts(data_dataset_counts = data_counts)

  testthat::expect_s3_class(res, "tbl_df")

  # Vegetation plots (150,000) before gridpoints (120,000); sPlotOpen
  #   before BIEN within the vegetation plots
  testthat::expect_equal(
    base::levels(dplyr::pull(res, dataset_type)),
    c("vegetation plot", "gridpoints", "traits", "fossil pollen archive")
  )

  testthat::expect_equal(
    base::as.character(dplyr::pull(res, dataset_source_type)),
    c("sPlotOpen", "BIEN", "gridpoints", "TRY", "Neotoma - FOSSILPOL")
  )

  testthat::expect_equal(
    dplyr::pull(res, n_datasets),
    c(90000L, 60000L, 120000L, 30000L, 4000L)
  )

  testthat::expect_named(
    res,
    c("dataset_type", "dataset_source_type", "n_datasets")
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_dataset_counts() keeps a missing source", {
  data_counts <-
    tibble::tibble(
      dataset_type = c("traits", "traits"),
      dataset_source_type = c("TRY", NA),
      n_datasets = c(5L, 2L)
    )

  res <-
    prepare_dataset_counts(data_dataset_counts = data_counts)

  testthat::expect_equal(
    base::as.character(dplyr::pull(res, dataset_source_type)),
    c("TRY", NA)
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_dataset_counts() requires its columns", {
  testthat::expect_error(
    prepare_dataset_counts(
      data_dataset_counts = tibble::tibble(dataset_type = "traits")
    ),
    regexp = "n_datasets"
  )
})
