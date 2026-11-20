#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_absolute_graphics_include() uses the full path", {
  res <-
    build_absolute_graphics_include(
      path = "Outputs/Figures/schema_diagram.png"
    )

  testthat::expect_s3_class(res, "knit_image_paths")

  testthat::expect_equal(
    base::as.character(res),
    here::here("Outputs/Figures/schema_diagram.png")
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("build_absolute_graphics_include() needs the file", {
  testthat::expect_error(
    build_absolute_graphics_include(path = "Outputs/Figures/missing.png"),
    regexp = "missing.png"
  )
})
