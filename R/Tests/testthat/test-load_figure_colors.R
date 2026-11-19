#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_figure_colors() returns snake case names", {
  path_colors <-
    base::file.path(withr::local_tempdir(), "colors.json")

  base::writeLines(
    text = c(
      '{"black": "#242531ff",',
      '"brownLight": "#bc7052",',
      '"greenDark": "#5f634fff"}'
    ),
    con = path_colors
  )

  res <-
    load_figure_colors(path_colors = path_colors)

  testthat::expect_type(res, "list")

  testthat::expect_named(res, c("black", "brown_light", "green_dark"))

  testthat::expect_equal(
    res,
    list(
      black = "#242531ff",
      brown_light = "#bc7052",
      green_dark = "#5f634fff"
    )
  )
})

testthat::test_that("load_figure_colors() reads the project colours", {
  res <-
    load_figure_colors(path_colors = here::here("colors.json"))

  testthat::expect_true(
    base::all(
      c(
        "black", "white", "grey", "green_light", "green_dark",
        "purple_light", "blue_dark", "brown_light", "beige_light"
      ) %in% base::names(res)
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_figure_colors() refuses values not colours", {
  path_colors <-
    base::file.path(withr::local_tempdir(), "colors.json")

  base::writeLines(
    text = '{"black": "#242531ff", "white": "white"}',
    con = path_colors
  )

  testthat::expect_error(
    load_figure_colors(path_colors = path_colors),
    regexp = "white"
  )
})

testthat::test_that("load_figure_colors() refuses a file without colours", {
  path_colors <-
    base::file.path(withr::local_tempdir(), "colors.json")

  base::writeLines(text = '["#242531ff", "#ffffff"]', con = path_colors)

  testthat::expect_error(
    load_figure_colors(path_colors = path_colors),
    regexp = "colour"
  )
})

testthat::test_that("load_figure_colors() validates its argument", {
  testthat::expect_error(
    load_figure_colors(
      path_colors = base::file.path(withr::local_tempdir(), "none.json")
    ),
    regexp = "path_colors"
  )

  testthat::expect_error(
    load_figure_colors(path_colors = 1),
    regexp = "path_colors"
  )
})
