#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_plot_climate() joins richness and climate", {
  data_raw <-
    tibble::tibble(
      dataset_type = c(
        base::rep("vegetation_plot", 7L), "gridpoints", "gridpoints"
      ),
      sample_id = c(1L, 1L, 2L, 5L, 5L, 6L, 6L, 3L, 4L),
      sample_id_link = c(base::rep(NA_integer_, 7L), 1L, 2L),
      coord_long = c(14, 14, 16, 15, 15, 17, 17, 14.1, 16.1),
      coord_lat = c(50, 50, 49.5, 49, 49, 50, 50, 50.1, 49.6),
      taxon_id = c(1L, 4L, 4L, 1L, 4L, 1L, 2L, NA, NA),
      value = c(5, 3, 2, 1, 0, 2, 3, NA, NA),
      abiotic_variable_unit = c(
        base::rep(NA_character_, 7L), "\u00b0C", "\u00b0C"
      ),
      abiotic_value = c(base::rep(NA_real_, 7L), 8.5, 9)
    )

  res <-
    prepare_plot_climate(data_plot_climate_raw = data_raw)

  testthat::expect_s3_class(res, "tbl_df")

  # Plot 2 and plot 5 have one taxon present; plot 6 has no gridpoint
  testthat::expect_equal(
    res,
    tibble::tibble(
      sample_id = 1L,
      coord_long = 14,
      coord_lat = 50,
      n_taxa = 2L,
      abiotic_variable_unit = "\u00b0C",
      abiotic_value = 8.5
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_plot_climate() requires its columns", {
  testthat::expect_error(
    prepare_plot_climate(
      data_plot_climate_raw = tibble::tibble(sample_id = 1L)
    ),
    regexp = "abiotic_value"
  )
})
