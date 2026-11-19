#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("compute_log_axis_max() adds one decade of room", {
  testthat::expect_equal(compute_log_axis_max(n_max = 950000), 1e7)

  testthat::expect_equal(compute_log_axis_max(n_max = 200000), 1e7)

  testthat::expect_equal(compute_log_axis_max(n_max = 1e6), 1e7)

  testthat::expect_equal(compute_log_axis_max(n_max = 3), 100)

  testthat::expect_equal(compute_log_axis_max(n_max = 1), 10)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("compute_log_axis_max() needs a positive count", {
  testthat::expect_error(
    compute_log_axis_max(n_max = -1),
    regexp = "n_max"
  )

  testthat::expect_error(
    compute_log_axis_max(n_max = NA_real_),
    regexp = "n_max"
  )
})
