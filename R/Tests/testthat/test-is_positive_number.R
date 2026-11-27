#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("is_positive_number() accepts one positive number", {
  testthat::expect_true(is_positive_number(x = 89))

  testthat::expect_true(is_positive_number(x = 0.1))

  testthat::expect_true(is_positive_number(x = 3L))
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("is_positive_number() refuses everything else", {
  list_invalid <-
    list(0, -1, NA_real_, NaN, Inf, c(1, 2), "1", NULL, list(1), TRUE)

  vec_res <-
    purrr::map_lgl(.x = list_invalid, .f = is_positive_number)

  testthat::expect_equal(
    vec_res,
    base::rep(FALSE, base::length(list_invalid))
  )
})
