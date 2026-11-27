#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("save_icon_png() writes the icon as a PNG file", {
  path_output <-
    base::file.path(withr::local_tempdir(), "icons", "seedling.png")

  res <-
    save_icon_png(
      icon = "seedling",
      fill = "#3ddc47",
      path_output = path_output,
      height_px = 64L
    )

  testthat::expect_equal(res, path_output)

  testthat::expect_true(base::file.exists(path_output))

  data_info <-
    magick::image_info(magick::image_read(path_output))

  testthat::expect_equal(dplyr::pull(data_info, format), "PNG")

  testthat::expect_equal(dplyr::pull(data_info, height), 64L)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("save_icon_png() draws the icon in its fill colour", {
  path_output <-
    base::file.path(withr::local_tempdir(), "square.png")

  save_icon_png(
    icon = "square",
    fill = "#156064",
    path_output = path_output,
    height_px = 32L
  )

  # The middle of the solid square has the fill colour
  array_pixels <-
    magick::image_read(path_output) |>
    magick::image_data(channels = "rgb")

  testthat::expect_equal(
    base::as.integer(array_pixels[, 14, 16]),
    c(0x15L, 0x60L, 0x64L)
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_icon_png() refuses unknown icons and colours", {
  path_output <-
    base::file.path(withr::local_tempdir(), "icon.png")

  testthat::expect_error(
    save_icon_png(
      icon = "no-such-icon",
      fill = "#156064",
      path_output = path_output
    ),
    regexp = "no-such-icon"
  )

  testthat::expect_error(
    save_icon_png(
      icon = "square",
      fill = "teal",
      path_output = path_output
    ),
    regexp = "RRGGBB"
  )

  testthat::expect_error(
    save_icon_png(
      icon = "square",
      fill = "#156064",
      path_output = path_output,
      height_px = 0L
    ),
    regexp = "height_px"
  )

  testthat::expect_false(base::file.exists(path_output))
})
