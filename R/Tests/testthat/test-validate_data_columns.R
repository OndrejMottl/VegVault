#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_data_columns() returns its data", {
  data_example <-
    tibble::tibble(a = 1L, b = "x", c = TRUE)

  testthat::expect_invisible(
    validate_data_columns(
      data_source = data_example,
      vec_columns_required = c("a", "b"),
      name_argument = "data_example"
    )
  )

  res <-
    validate_data_columns(
      data_source = data_example,
      vec_columns_required = c("a", "b"),
      name_argument = "data_example"
    )

  testthat::expect_equal(res, data_example)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_data_columns() names the missing columns", {
  res_error <-
    testthat::expect_error(
      validate_data_columns(
        data_source = tibble::tibble(a = 1L),
        vec_columns_required = c("a", "sample_id", "coord_long"),
        name_argument = "data_example"
      ),
      regexp = "data_example"
    )

  testthat::expect_match(
    base::conditionMessage(res_error),
    "sample_id"
  )

  testthat::expect_match(
    base::conditionMessage(res_error),
    "coord_long"
  )
})

testthat::test_that("validate_data_columns() refuses other objects", {
  testthat::expect_error(
    validate_data_columns(
      data_source = list(a = 1L),
      vec_columns_required = "a",
      name_argument = "data_example"
    ),
    regexp = "data_example.*data frame"
  )
})
