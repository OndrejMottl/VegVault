# The attributes dbml-renderer 1.0.31 writes, one element each
text_svg_renderer <-
  stringr::str_c(
    "<svg>",
    "<polygon fill=\"#1d71b8\" stroke=\"transparent\"/>",
    "<text font-family=\"Helvetica,sans-Serif\" fill=\"#ffffff\">T</text>",
    "<polygon fill=\"#e7e2dd\" stroke=\"transparent\"/>",
    "<polygon fill=\"none\" stroke=\"#29235c\"/>",
    "<text font-family=\"Helvetica,sans-Serif\" fill=\"#29235c\">c</text>",
    "<ellipse fill=\"none\" stroke=\"black\" stroke-width=\"0\"/>",
    "</svg>"
  )

list_theme_website <-
  base::list(
    header = "#8a554e",
    body = "#ffffff",
    text = "#242531",
    line = "#5f634f",
    font = "Inter, Helvetica, sans-serif"
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_diagram_svg() replaces colours and font", {
  res <-
    prepare_diagram_svg(
      text_svg = text_svg_renderer,
      list_theme = list_theme_website
    )

  testthat::expect_type(res, "character")

  testthat::expect_equal(
    res,
    stringr::str_c(
      "<svg>",
      "<polygon fill=\"#8a554e\" stroke=\"transparent\"/>",
      "<text font-family=\"Inter, Helvetica, sans-serif\" ",
      "fill=\"#ffffff\">T</text>",
      "<polygon fill=\"#ffffff\" stroke=\"transparent\"/>",
      "<polygon fill=\"none\" stroke=\"#5f634f\"/>",
      "<text font-family=\"Inter, Helvetica, sans-serif\" ",
      "fill=\"#242531\">c</text>",
      "<ellipse fill=\"none\" stroke=\"black\" stroke-width=\"0\"/>",
      "</svg>"
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_diagram_svg() needs the renderer's colours", {
  testthat::expect_error(
    prepare_diagram_svg(
      text_svg = stringr::str_remove(
        string = text_svg_renderer,
        pattern = "fill=\"#e7e2dd\""
      ),
      list_theme = list_theme_website
    ),
    regexp = "e7e2dd"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_diagram_svg() validates the theme", {
  testthat::expect_error(
    prepare_diagram_svg(
      text_svg = text_svg_renderer,
      list_theme = purrr::list_modify(list_theme_website, line = NULL)
    ),
    regexp = "list_theme"
  )

  testthat::expect_error(
    prepare_diagram_svg(
      text_svg = text_svg_renderer,
      list_theme = purrr::list_modify(list_theme_website, body = "#ffffffff")
    ),
    regexp = "list_theme"
  )
})

testthat::test_that("prepare_diagram_svg() needs one SVG text", {
  testthat::expect_error(
    prepare_diagram_svg(
      text_svg = c(text_svg_renderer, text_svg_renderer),
      list_theme = list_theme_website
    ),
    regexp = "text_svg"
  )
})
