#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("summarise_trait_by_taxon() averages per taxon", {
  data_raw <-
    tibble::tibble(
      dataset_type = c(
        "traits", "traits", "traits", "traits", "fossil_pollen_archive"
      ),
      taxon_id_trait = c(5L, 2L, 2L, 5L, NA),
      trait_value = c(20, 30, 40, NA, NA)
    )

  res <-
    summarise_trait_by_taxon(data_trait_example_raw = data_raw)

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(
    res,
    tibble::tibble(
      taxon_id_trait = c(2L, 5L),
      trait_value_mean = c(35, 20)
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("summarise_trait_by_taxon() requires its columns", {
  testthat::expect_error(
    summarise_trait_by_taxon(
      data_trait_example_raw = tibble::tibble(taxon_id_trait = 1L)
    ),
    regexp = "trait_value"
  )
})
