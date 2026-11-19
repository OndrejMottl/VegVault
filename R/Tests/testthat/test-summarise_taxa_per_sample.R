#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("summarise_taxa_per_sample() counts taxa present", {
  data_raw <-
    tibble::tibble(
      dataset_type = c(
        base::rep("fossil_pollen_archive", 5L), "traits"
      ),
      dataset_id = c(8L, 8L, 8L, 12L, 12L, 9L),
      sample_id = c(9L, 9L, 10L, 30L, 30L, 11L),
      coord_long = c(-70, -70, -70, -60, -60, -65),
      coord_lat = c(-20, -20, -20, -10, -10, -15),
      taxon_id = c(5L, 2L, 5L, 2L, 5L, NA),
      value = c(2, 6, 1, 0, 3, NA)
    )

  res <-
    summarise_taxa_per_sample(data_trait_example_raw = data_raw)

  testthat::expect_s3_class(res, "tbl_df")

  # Sample 10 has one taxon; sample 30 has one taxon with a value above 0
  testthat::expect_equal(
    res,
    tibble::tibble(
      dataset_id = 8L,
      sample_id = 9L,
      coord_long = -70,
      coord_lat = -20,
      n_taxa = 2L
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("summarise_taxa_per_sample() requires its columns", {
  testthat::expect_error(
    summarise_taxa_per_sample(
      data_trait_example_raw = tibble::tibble(dataset_id = 1L)
    ),
    regexp = "taxon_id"
  )
})
