#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_lookup_ids() validates arguments", {
  testthat::expect_error(
    prepare_lookup_ids(
      data_values = tibble::tibble(taxon_name = "a"),
      vec_key_columns = "taxon_name",
      name_id = "taxon_id",
      name_table = "Taxa"
    ),
    regexp = "source_order"
  )

  testthat::expect_error(
    prepare_lookup_ids(
      data_values = tibble::tibble(source_order = 1L, taxon_name = "a"),
      vec_key_columns = "missing_column",
      name_id = "taxon_id",
      name_table = "Taxa"
    ),
    regexp = "vec_key_columns"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_lookup_ids() numbers by source and value", {
  data_values <-
    tibble::tibble(
      source_order = c(2L, 1L, 1L, 3L, 2L),
      taxon_name = c("b", "c", "a", "a", "c")
    )

  res <-
    prepare_lookup_ids(
      data_values = data_values,
      vec_key_columns = "taxon_name",
      name_id = "taxon_id",
      name_table = "Taxa"
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(res, c("taxon_id", "taxon_name"))
  testthat::expect_equal(dplyr::pull(res, taxon_id), c(1L, 2L, 3L))
  testthat::expect_equal(dplyr::pull(res, taxon_name), c("a", "c", "b"))
})

testthat::test_that("prepare_lookup_ids() handles keys of several columns", {
  data_values <-
    tibble::tibble(
      source_order = c(1L, 1L, 2L, 2L),
      sample_size = c(25, 10, 10, NA_real_),
      sample_size_description = c("m2", "m2", "m2", NA_character_)
    )

  res <-
    prepare_lookup_ids(
      data_values = data_values,
      vec_key_columns = c("sample_size", "sample_size_description"),
      name_id = "sample_size_id",
      name_table = "SampleSizeID"
    )

  # The row without a value is not a value
  testthat::expect_equal(dplyr::pull(res, sample_size), c(10, 25))
  testthat::expect_equal(dplyr::pull(res, sample_size_id), c(1L, 2L))
})


#----------------------------------------------------------#
# Edge cases and errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_lookup_ids() refuses partly missing keys", {
  testthat::expect_error(
    prepare_lookup_ids(
      data_values = tibble::tibble(
        source_order = 1L,
        sample_size = 10,
        sample_size_description = NA_character_
      ),
      vec_key_columns = c("sample_size", "sample_size_description"),
      name_id = "sample_size_id",
      name_table = "SampleSizeID"
    ),
    regexp = "SampleSizeID"
  )
})

testthat::test_that("prepare_lookup_ids() returns no rows for no values", {
  res <-
    prepare_lookup_ids(
      data_values = tibble::tibble(
        source_order = 1L,
        taxon_name = NA_character_
      ),
      vec_key_columns = "taxon_name",
      name_id = "taxon_id",
      name_table = "Taxa"
    )

  testthat::expect_equal(base::nrow(res), 0L)
  testthat::expect_named(res, c("taxon_id", "taxon_name"))
})
