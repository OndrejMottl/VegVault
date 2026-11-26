# Two tables in the form dbml-renderer writes them, already in the colours
#   of the website: header #8a554e with white text, white rows
text_svg_tables <-
  stringr::str_c(
    "<svg>\n",
    "<g id=\"Alpha\" class=\"node\">\n<title>Alpha</title>\n",
    "<polygon fill=\"#8a554e\" stroke=\"transparent\"/>\n",
    "<text font-weight=\"bold\" fill=\"#ffffff\">Alpha</text>\n",
    "<polygon fill=\"#ffffff\" stroke=\"transparent\"/>\n",
    "<text fill=\"#242531\">alpha_id</text>\n",
    "</g>\n",
    "<g id=\"Beta\" class=\"node\">\n<title>Beta</title>\n",
    "<polygon fill=\"#8a554e\" stroke=\"transparent\"/>\n",
    "<text font-weight=\"bold\" fill=\"#ffffff\">Beta</text>\n",
    "<polygon fill=\"#ffffff\" stroke=\"transparent\"/>\n",
    "</g>\n",
    "</svg>\n"
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_diagram_table_colors() recolours one table", {
  res <-
    prepare_diagram_table_colors(
      text_svg = text_svg_tables,
      data_table_colors = tibble::tibble(
        table_name = "Alpha",
        fill = "#156064",
        text = "#000000"
      ),
      color_header = "#8a554e"
    )

  testthat::expect_type(res, "character")

  testthat::expect_equal(
    res,
    stringr::str_c(
      "<svg>\n",
      "<g id=\"Alpha\" class=\"node\">\n<title>Alpha</title>\n",
      "<polygon fill=\"#156064\" stroke=\"transparent\"/>\n",
      "<text font-weight=\"bold\" fill=\"#000000\">Alpha</text>\n",
      "<polygon fill=\"#ffffff\" stroke=\"transparent\"/>\n",
      "<text fill=\"#242531\">alpha_id</text>\n",
      "</g>\n",
      "<g id=\"Beta\" class=\"node\">\n<title>Beta</title>\n",
      "<polygon fill=\"#8a554e\" stroke=\"transparent\"/>\n",
      "<text font-weight=\"bold\" fill=\"#ffffff\">Beta</text>\n",
      "<polygon fill=\"#ffffff\" stroke=\"transparent\"/>\n",
      "</g>\n",
      "</svg>\n"
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("prepare_diagram_table_colors() skips absent tables", {
  res <-
    prepare_diagram_table_colors(
      text_svg = text_svg_tables,
      data_table_colors = tibble::tibble(
        table_name = c("Gamma", "Beta"),
        fill = c("#5f634f", "#242531"),
        text = c("#ffffff", "#ffffff")
      ),
      color_header = "#8a554e"
    )

  testthat::expect_equal(
    stringr::str_count(res, stringr::fixed("fill=\"#242531\" stroke")),
    1L
  )

  testthat::expect_equal(
    stringr::str_count(res, stringr::fixed("fill=\"#8a554e\"")),
    1L
  )

  testthat::expect_false(stringr::str_detect(res, "5f634f"))
})

testthat::test_that("prepare_diagram_table_colors() matches whole names", {
  # Table Beta renamed to AlphaValue, whose name starts with Alpha
  text_svg_prefix <-
    stringr::str_replace_all(text_svg_tables, "Beta", "AlphaValue")

  pattern_group_value <-
    stringr::regex(
      "<g id=\"AlphaValue\" class=\"node\">.*?</g>",
      dotall = TRUE
    )

  res_alpha <-
    prepare_diagram_table_colors(
      text_svg = text_svg_prefix,
      data_table_colors = tibble::tibble(
        table_name = "Alpha", fill = "#156064", text = "#000000"
      ),
      color_header = "#8a554e"
    )

  testthat::expect_equal(
    stringr::str_extract(res_alpha, pattern_group_value),
    stringr::str_extract(text_svg_prefix, pattern_group_value)
  )

  res_value <-
    prepare_diagram_table_colors(
      text_svg = text_svg_prefix,
      data_table_colors = tibble::tibble(
        table_name = "AlphaValue", fill = "#156064", text = "#000000"
      ),
      color_header = "#8a554e"
    )

  testthat::expect_equal(
    stringr::str_extract(
      res_value,
      stringr::regex("<g id=\"Alpha\" class=\"node\">.*?</g>", dotall = TRUE)
    ),
    stringr::str_extract(
      text_svg_prefix,
      stringr::regex("<g id=\"Alpha\" class=\"node\">.*?</g>", dotall = TRUE)
    )
  )

  testthat::expect_true(
    stringr::str_detect(
      stringr::str_extract(res_value, pattern_group_value),
      stringr::fixed("fill=\"#156064\"")
    )
  )
})

testthat::test_that("prepare_diagram_table_colors() needs the header fill", {
  # The diagram is drawn with the header in lower case, so an upper-case
  #   header colour finds no header to recolour
  testthat::expect_error(
    prepare_diagram_table_colors(
      text_svg = text_svg_tables,
      data_table_colors = tibble::tibble(
        table_name = "Alpha", fill = "#156064", text = "#ffffff"
      ),
      color_header = "#8A554E"
    ),
    regexp = "Alpha"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_diagram_table_colors() validates arguments", {
  testthat::expect_error(
    prepare_diagram_table_colors(
      text_svg = text_svg_tables,
      data_table_colors = tibble::tibble(
        table_name = "Alpha", fill = "#156064"
      ),
      color_header = "#8a554e"
    ),
    regexp = "data_table_colors"
  )

  testthat::expect_error(
    prepare_diagram_table_colors(
      text_svg = text_svg_tables,
      data_table_colors = tibble::tibble(
        table_name = "Alpha", fill = "teal", text = "#ffffff"
      ),
      color_header = "#8a554e"
    ),
    regexp = "RRGGBB"
  )

  testthat::expect_error(
    prepare_diagram_table_colors(
      text_svg = text_svg_tables,
      data_table_colors = tibble::tibble(
        table_name = c("Alpha", "Alpha"),
        fill = c("#156064", "#156064"),
        text = c("#ffffff", "#ffffff")
      ),
      color_header = "#8a554e"
    ),
    regexp = "twice"
  )

  testthat::expect_error(
    prepare_diagram_table_colors(
      text_svg = c(text_svg_tables, text_svg_tables),
      data_table_colors = tibble::tibble(
        table_name = "Alpha", fill = "#156064", text = "#ffffff"
      ),
      color_header = "#8a554e"
    ),
    regexp = "text_svg"
  )
})
