#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_figure_style() returns the documented parts", {
  res <-
    build_figure_style(
      list_graphical = list(
        text_size = 14,
        line_size = 0.1,
        point_size = 3,
        text_wrap_width = 60,
        image_units = "mm",
        image_width = list(single = 89, double = 183, full = 247),
        colors = list(grey = "#999999", brown_neutral = "#5F634F")
      ),
      list_colors = list(
        black = "#242531ff",
        white = "#ffffffff",
        grey = "#999999ff",
        brown_neutral = "#8B6965ff",
        green_light = "#3ddc47ff",
        green_dark = "#5f634fff",
        purple_light = "#aa6da3ff",
        blue_dark = "#156064ff"
      )
    )

  testthat::expect_named(
    res,
    c(
      "theme", "text_size", "line_size", "point_size", "text_wrap_width",
      "image_units", "image_width", "colors", "palettes"
    ),
    ignore.order = TRUE
  )

  testthat::expect_true(ggplot2::is_theme(purrr::chuck(res, "theme")))

  testthat::expect_equal(
    purrr::chuck(res, "image_width"),
    c(single = 89, double = 183, full = 247)
  )

  testthat::expect_equal(purrr::chuck(res, "point_size"), 3)

  testthat::expect_equal(purrr::chuck(res, "image_units"), "mm")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_figure_style() lets manuscript colours win", {
  res <-
    build_figure_style(
      list_graphical = list(
        text_size = 14,
        line_size = 0.1,
        point_size = 3,
        text_wrap_width = 60,
        image_units = "mm",
        image_width = list(full = 247),
        colors = list(brown_neutral = "#5F634F", red = "red")
      ),
      list_colors = list(
        black = "#242531ff",
        white = "#ffffffff",
        grey = "#999999ff",
        brown_neutral = "#8B6965ff",
        green_light = "#3ddc47ff",
        green_dark = "#5f634fff",
        purple_light = "#aa6da3ff",
        blue_dark = "#156064ff"
      )
    )

  list_colors_res <-
    purrr::chuck(res, "colors")

  testthat::expect_equal(
    purrr::chuck(list_colors_res, "brown_neutral"),
    "#5F634F"
  )

  testthat::expect_equal(purrr::chuck(list_colors_res, "red"), "red")

  testthat::expect_equal(
    purrr::chuck(list_colors_res, "black"),
    "#242531ff"
  )
})

testthat::test_that("build_figure_style() builds the v1 palettes", {
  res <-
    build_figure_style(
      list_graphical = list(
        text_size = 14,
        line_size = 0.1,
        point_size = 3,
        text_wrap_width = 60,
        image_units = "mm",
        image_width = list(full = 247),
        colors = list()
      ),
      list_colors = list(
        black = "#000000",
        white = "#ffffff",
        grey = "#999999",
        green_light = "#00ff00",
        green_dark = "#003300",
        purple_light = "#ff00ff",
        blue_dark = "#000033"
      )
    )

  list_palettes <-
    purrr::chuck(res, "palettes")

  testthat::expect_equal(
    purrr::chuck(list_palettes, "dataset_type"),
    c(
      "vegetation plot" = "#00ff00",
      "fossil pollen archive" = "#ff00ff",
      "traits" = "#000033",
      "gridpoints" = "#003300"
    )
  )

  testthat::expect_equal(
    purrr::chuck(list_palettes, "dataset_source_type"),
    c(
      "BIEN" = "#00ff00",
      "sPlotOpen" = "#00ff00",
      "Neotoma - FOSSILPOL" = "#ff00ff",
      "TRY" = "#000033",
      "gridpoints" = "#003300"
    )
  )
})

testthat::test_that("build_figure_style() sets the v1 theme", {
  res <-
    build_figure_style(
      list_graphical = list(
        text_size = 14,
        line_size = 0.1,
        point_size = 3,
        text_wrap_width = 60,
        image_units = "mm",
        image_width = list(full = 247),
        colors = list(grey = "#999999")
      ),
      list_colors = list(
        black = "#242531ff",
        white = "#ffffffff",
        green_light = "#3ddc47ff",
        green_dark = "#5f634fff",
        purple_light = "#aa6da3ff",
        blue_dark = "#156064ff"
      )
    )

  theme_res <-
    purrr::chuck(res, "theme")

  element_axis_text <-
    ggplot2::calc_element(element = "axis.text", theme = theme_res)

  testthat::expect_equal(purrr::chuck(element_axis_text, "size"), 14)

  testthat::expect_equal(
    purrr::chuck(element_axis_text, "colour"),
    "#242531ff"
  )

  element_panel <-
    ggplot2::calc_element(element = "panel.background", theme = theme_res)

  testthat::expect_equal(purrr::chuck(element_panel, "fill"), "#ffffffff")

  testthat::expect_equal(purrr::chuck(element_panel, "colour"), "#999999")

  testthat::expect_s3_class(
    ggplot2::calc_element(element = "panel.grid.minor", theme = theme_res),
    "ggplot2::element_blank"
  )
})

testthat::test_that("build_figure_style() works with the project config", {
  res <-
    build_figure_style(
      list_graphical = load_config_value(
        value = c("graphical", "manuscript")
      ),
      list_colors = load_figure_colors(
        path_colors = here::here("colors.json")
      )
    )

  testthat::expect_true(ggplot2::is_theme(purrr::chuck(res, "theme")))

  testthat::expect_equal(
    base::names(purrr::chuck(res, "image_width")),
    c("single", "double", "full")
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_figure_style() requires its colours", {
  testthat::expect_error(
    build_figure_style(
      list_graphical = list(
        text_size = 14,
        line_size = 0.1,
        point_size = 3,
        text_wrap_width = 60,
        image_units = "mm",
        image_width = list(full = 247),
        colors = list()
      ),
      list_colors = list(black = "#000000", white = "#ffffff")
    ),
    regexp = "green_light"
  )
})

testthat::test_that("build_figure_style() requires its settings", {
  list_colors <-
    list(
      black = "#000000",
      white = "#ffffff",
      grey = "#999999",
      green_light = "#00ff00",
      green_dark = "#003300",
      purple_light = "#ff00ff",
      blue_dark = "#000033"
    )

  testthat::expect_error(
    build_figure_style(
      list_graphical = list(text_size = 14),
      list_colors = list_colors
    ),
    regexp = "line_size"
  )

  testthat::expect_error(
    build_figure_style(
      list_graphical = list(
        text_size = "14",
        line_size = 0.1,
        point_size = 3,
        text_wrap_width = 60,
        image_units = "mm",
        image_width = list(full = 247),
        colors = list()
      ),
      list_colors = list_colors
    ),
    regexp = "text_size"
  )

  testthat::expect_error(
    build_figure_style(list_graphical = "a", list_colors = list_colors),
    regexp = "list_graphical"
  )
})
