#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("summarise_dataset_age_ranges() summarises ages", {
  data_raw <-
    tibble::tibble(
      dataset_type = c(
        "fossil_pollen_archive", "fossil_pollen_archive",
        "fossil_pollen_archive", "fossil_pollen_archive", "traits"
      ),
      dataset_id = c(8L, 8L, 8L, 10L, 9L),
      sample_id = c(9L, 9L, 10L, 20L, 11L),
      age = c(7000, 7000, 11000, 6000, NA)
    )

  res <-
    summarise_dataset_age_ranges(data_trait_example_raw = data_raw)

  testthat::expect_s3_class(res, "tbl_df")

  # Sample 9 appears twice (two taxa) but counts once in the mean
  testthat::expect_equal(
    res,
    tibble::tibble(
      dataset_id = c(8L, 10L),
      age_min = c(7000, 6000),
      age_mean = c(9000, 6000),
      age_max = c(11000, 6000)
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("summarise_dataset_age_ranges() requires its columns", {
  testthat::expect_error(
    summarise_dataset_age_ranges(
      data_trait_example_raw = tibble::tibble(dataset_id = 1L)
    ),
    regexp = "age"
  )
})
