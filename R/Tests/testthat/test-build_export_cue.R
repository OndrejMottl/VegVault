#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("build_export_cue() forces a rewrite when asked", {
  res <-
    build_export_cue(flag_rewrite = TRUE)

  testthat::expect_s3_class(res, "tar_cue")

  testthat::expect_equal(res[["mode"]], "always")
})

testthat::test_that("build_export_cue() otherwise writes when needed", {
  res <-
    build_export_cue(flag_rewrite = FALSE)

  testthat::expect_s3_class(res, "tar_cue")

  testthat::expect_equal(res[["mode"]], "thorough")

  # Missing or changed export files are checked
  testthat::expect_true(res[["file"]])
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_export_cue() validates its input", {
  testthat::expect_error(
    build_export_cue(flag_rewrite = NA),
    regexp = "flag_rewrite"
  )

  testthat::expect_error(
    build_export_cue(flag_rewrite = "yes"),
    regexp = "flag_rewrite"
  )

  testthat::expect_error(
    build_export_cue(flag_rewrite = c(TRUE, FALSE)),
    regexp = "flag_rewrite"
  )
})
