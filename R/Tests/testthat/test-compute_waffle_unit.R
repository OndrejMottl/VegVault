#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("compute_waffle_unit() gives 100 to 1000 squares", {
  # The v1 database: 426 squares of 1000 datasets
  testthat::expect_equal(compute_waffle_unit(n_total = 426225), 1000)

  testthat::expect_equal(compute_waffle_unit(n_total = 99999), 100)

  testthat::expect_equal(compute_waffle_unit(n_total = 100000), 1000)

  testthat::expect_equal(compute_waffle_unit(n_total = 3e6), 10000)
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("compute_waffle_unit() is at least one record", {
  testthat::expect_equal(compute_waffle_unit(n_total = 11), 1)

  testthat::expect_equal(compute_waffle_unit(n_total = 1), 1)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_waffle_unit() needs a positive count", {
  testthat::expect_error(
    compute_waffle_unit(n_total = 0),
    regexp = "n_total"
  )

  testthat::expect_error(
    compute_waffle_unit(n_total = c(1, 2)),
    regexp = "n_total"
  )
})
