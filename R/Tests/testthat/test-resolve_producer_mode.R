#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_producer_mode() returns the mode", {
  testthat::expect_equal(
    resolve_producer_mode(profile = "default", mode = "dev"),
    "dev"
  )

  testthat::expect_equal(
    resolve_producer_mode(profile = "subset", mode = "release"),
    "release"
  )

  testthat::expect_equal(
    resolve_producer_mode(profile = "release", mode = "release"),
    "release"
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("resolve_producer_mode() needs tags for a release", {
  testthat::expect_error(
    resolve_producer_mode(profile = "release", mode = "dev"),
    regexp = "release\\s+profile"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_producer_mode() validates its arguments", {
  testthat::expect_error(
    resolve_producer_mode(profile = "default", mode = "main"),
    regexp = "`mode`"
  )

  testthat::expect_error(
    resolve_producer_mode(profile = "default", mode = c("dev", "release")),
    regexp = "`mode`"
  )

  testthat::expect_error(
    resolve_producer_mode(profile = NA_character_, mode = "dev"),
    regexp = "`profile`"
  )
})
