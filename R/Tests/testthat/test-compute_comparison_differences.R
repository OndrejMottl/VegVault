#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_comparison_differences() validates arguments", {
  testthat::expect_error(
    compute_comparison_differences(
      data_v1 = tibble::tibble(scope = "a", key = 1),
      data_v2 = "rows"
    ),
    regexp = "data_v2"
  )

  testthat::expect_error(
    compute_comparison_differences(
      data_v1 = tibble::tibble(scope = "a", key = 1),
      data_v2 = tibble::tibble(scope = "a", other = 1)
    ),
    regexp = "columns"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("compute_comparison_differences() lists the rows", {
  data_v1 <-
    tibble::tibble(
      scope = c("a", "a", "a", "b"),
      name = c("x", "x", "y", "z"),
      value = c(1, 1, 2, 3)
    )

  data_v2 <-
    tibble::tibble(
      value = c(1, 2, 9),
      scope = c("a", "a", "a"),
      name = c("x", "y", "w")
    )

  res <-
    compute_comparison_differences(data_v1 = data_v1, data_v2 = data_v2)

  testthat::expect_equal(
    res,
    tibble::tibble(
      scope = c("a", "a", "b"),
      name = c("w", "x", "z"),
      value = c(9, 1, 3),
      n_v1 = c(0, 2, 1),
      n_v2 = c(1, 1, 0)
    )
  )
})

testthat::test_that("compute_comparison_differences() is empty when equal", {
  data_v1 <-
    tibble::tibble(scope = c("a", "b"), name = c("x", NA))

  res <-
    compute_comparison_differences(
      data_v1 = data_v1,
      data_v2 = dplyr::slice(data_v1, c(2L, 1L))
    )

  testthat::expect_equal(base::nrow(res), 0L)

  testthat::expect_named(res, c("scope", "name", "n_v1", "n_v2"))
})
