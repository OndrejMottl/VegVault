#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_unique_rows() accepts unique rows", {
  data_unique <-
    tibble::tibble(
      taxon_id = c(1L, 2L),
      taxon_name = c("Picea", "Quercus")
    )

  testthat::expect_true(validate_unique_rows(data_source = data_unique))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_unique_rows() ignores integer columns", {
  # The rows differ only in their integer ID
  data_duplicated <-
    tibble::tibble(
      taxon_id = c(1L, 2L),
      taxon_name = c("Picea", "Picea")
    )

  testthat::expect_error(
    validate_unique_rows(data_source = data_duplicated),
    regexp = "unique rows in the table data_duplicated"
  )
})

testthat::test_that("validate_unique_rows() refuses identical rows", {
  data_duplicated <-
    tibble::tibble(
      taxon_name = c("Picea", "Picea"),
      value = c(1, 1)
    )

  testthat::expect_error(
    validate_unique_rows(data_source = data_duplicated),
    regexp = "unique rows"
  )
})
