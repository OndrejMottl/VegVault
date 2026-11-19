#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_check_specs() accepts valid checks", {
  res <-
    diagnose_producer_check_specs(
      list_checks = base::list(
        range = base::list(min = -180, max = 180),
        finite = TRUE,
        whole_number = FALSE,
        not_empty = TRUE,
        allowed_values = c("published"),
        forbidden_values = c(6553.5, 0),
        pattern = "^[a-z]+$"
      ),
      field_path = "columns[1].checks"
    )

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 0L)
})

testthat::test_that("diagnose_producer_check_specs() accepts NULL", {
  res <-
    diagnose_producer_check_specs(
      list_checks = NULL,
      field_path = "columns[1].checks"
    )

  testthat::expect_length(res, 0L)
})

testthat::test_that("diagnose_producer_check_specs() accepts half ranges", {
  res <-
    diagnose_producer_check_specs(
      list_checks = base::list(
        range = base::list(min = 0, min_inclusive = FALSE)
      ),
      field_path = "variables.table[2].checks"
    )

  testthat::expect_length(res, 0L)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_check_specs() flags unknown names", {
  res <-
    diagnose_producer_check_specs(
      list_checks = base::list(maximum = 5),
      field_path = "columns[4].checks"
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(res, "^columns\\[4\\]\\.checks")

  testthat::expect_match(res, "maximum")
})

testthat::test_that("diagnose_producer_check_specs() flags bad ranges", {
  res_empty <-
    diagnose_producer_check_specs(
      list_checks = base::list(range = base::list(min_inclusive = TRUE)),
      field_path = "c"
    )

  testthat::expect_length(res_empty, 1L)

  res_reversed <-
    diagnose_producer_check_specs(
      list_checks = base::list(range = base::list(min = 5, max = 1)),
      field_path = "c"
    )

  testthat::expect_length(res_reversed, 1L)

  res_text <-
    diagnose_producer_check_specs(
      list_checks = base::list(range = base::list(min = "a")),
      field_path = "c"
    )

  testthat::expect_length(res_text, 1L)

  res_unknown <-
    diagnose_producer_check_specs(
      list_checks = base::list(range = base::list(min = 0, lower = 1)),
      field_path = "c"
    )

  testthat::expect_length(res_unknown, 1L)

  testthat::expect_match(res_unknown, "lower")
})

testthat::test_that("diagnose_producer_check_specs() flags bad arguments", {
  res_flag <-
    diagnose_producer_check_specs(
      list_checks = base::list(finite = "yes"),
      field_path = "c"
    )

  testthat::expect_length(res_flag, 1L)

  testthat::expect_match(res_flag, "finite")

  res_values <-
    diagnose_producer_check_specs(
      list_checks = base::list(allowed_values = base::character(0)),
      field_path = "c"
    )

  testthat::expect_length(res_values, 1L)

  testthat::expect_match(res_values, "allowed_values")

  res_missing <-
    diagnose_producer_check_specs(
      list_checks = base::list(forbidden_values = c(1, NA)),
      field_path = "c"
    )

  testthat::expect_length(res_missing, 1L)

  testthat::expect_match(res_missing, "forbidden_values")

  res_pattern <-
    diagnose_producer_check_specs(
      list_checks = base::list(pattern = "([a-z]"),
      field_path = "c"
    )

  testthat::expect_length(res_pattern, 1L)

  testthat::expect_match(res_pattern, "pattern")
})

testthat::test_that("diagnose_producer_check_specs() reports every problem", {
  res <-
    diagnose_producer_check_specs(
      list_checks = base::list(
        maximum = 5,
        finite = "yes",
        pattern = "("
      ),
      field_path = "c"
    )

  testthat::expect_length(res, 3L)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_check_specs() validates arguments", {
  testthat::expect_error(
    diagnose_producer_check_specs(
      list_checks = base::list(finite = TRUE),
      field_path = 1
    ),
    regexp = "field_path"
  )

  res_unnamed <-
    diagnose_producer_check_specs(
      list_checks = base::list(TRUE),
      field_path = "c"
    )

  testthat::expect_length(res_unnamed, 1L)

  testthat::expect_match(res_unnamed, "named")
})
