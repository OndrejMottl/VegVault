#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_reference_links() validates arguments", {
  data_references <-
    tibble::tibble(reference_id = 1L, reference_detail = "A")

  data_samples <-
    tibble::tibble(sample_id = 1L, sample_name = "s1")

  testthat::expect_error(
    prepare_reference_links(
      data_links = tibble::tibble(sample_name = "s1"),
      data_entity_ids = data_samples,
      data_reference_ids = data_references,
      vec_entity_keys = "sample_name",
      name_entity_id = "sample_id",
      name_table = "SampleReference"
    ),
    regexp = "reference_detail"
  )

  testthat::expect_error(
    prepare_reference_links(
      data_links = tibble::tibble(sample_name = "s1", reference_detail = "A"),
      data_entity_ids = data_samples,
      data_reference_ids = tibble::tibble(reference_detail = "A"),
      vec_entity_keys = "sample_name",
      name_entity_id = "sample_id",
      name_table = "SampleReference"
    ),
    regexp = "data_reference_ids"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_reference_links() gives distinct id pairs", {
  res <-
    prepare_reference_links(
      data_links = tibble::tibble(
        sample_name = c("s2", "s1", "s1", "s2", "s1"),
        reference_detail = c("B", "A", "A", NA_character_, "B")
      ),
      data_entity_ids = tibble::tibble(
        sample_id = c(1L, 2L),
        sample_name = c("s1", "s2")
      ),
      data_reference_ids = tibble::tibble(
        reference_id = c(1L, 2L),
        reference_detail = c("A", "B")
      ),
      vec_entity_keys = "sample_name",
      name_entity_id = "sample_id",
      name_table = "SampleReference"
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(res, c("sample_id", "reference_id"))
  testthat::expect_equal(dplyr::pull(res, sample_id), c(1L, 1L, 2L))
  testthat::expect_equal(dplyr::pull(res, reference_id), c(1L, 2L, 2L))
  testthat::expect_type(dplyr::pull(res, reference_id), "integer")
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_reference_links() refuses unknown keys", {
  data_entity_ids <-
    tibble::tibble(sample_id = 1L, sample_name = "s1")

  data_reference_ids <-
    tibble::tibble(reference_id = 1L, reference_detail = "A")

  testthat::expect_error(
    prepare_reference_links(
      data_links = tibble::tibble(sample_name = "s9", reference_detail = "A"),
      data_entity_ids = data_entity_ids,
      data_reference_ids = data_reference_ids,
      vec_entity_keys = "sample_name",
      name_entity_id = "sample_id",
      name_table = "SampleReference"
    ),
    regexp = "SampleReference"
  )

  testthat::expect_error(
    prepare_reference_links(
      data_links = tibble::tibble(sample_name = "s1", reference_detail = "Z"),
      data_entity_ids = data_entity_ids,
      data_reference_ids = data_reference_ids,
      vec_entity_keys = "sample_name",
      name_entity_id = "sample_id",
      name_table = "SampleReference"
    ),
    regexp = "SampleReference"
  )
})
