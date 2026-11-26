list_theme_test <-
  base::list(
    header = "#8a554e",
    body = "#ffffff",
    text = "#242531",
    line = "#242531",
    font = "Inter, Helvetica, sans-serif"
  )


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("render_schema_diagram() validates its arguments", {
  path_output <-
    base::file.path(withr::local_tempdir(), "diagram.svg")

  testthat::expect_error(
    render_schema_diagram(
      text_dbml = c("Table A {", "}"),
      path_output = path_output,
      list_theme = list_theme_test,
      renderer = "renderer@1.0.0",
      path_npx = "npx"
    ),
    regexp = "text_dbml"
  )

  testthat::expect_error(
    render_schema_diagram(
      text_dbml = "Table A {\n  a_id INTEGER [pk]\n}\n",
      path_output = NA_character_,
      list_theme = list_theme_test,
      renderer = "renderer@1.0.0",
      path_npx = "npx"
    ),
    regexp = "path_output"
  )

  testthat::expect_error(
    render_schema_diagram(
      text_dbml = "Table A {\n  a_id INTEGER [pk]\n}\n",
      path_output = path_output,
      list_theme = list_theme_test,
      renderer = "",
      path_npx = "npx"
    ),
    regexp = "renderer"
  )

  testthat::expect_error(
    render_schema_diagram(
      text_dbml = "Table A {\n  a_id INTEGER [pk]\n}\n",
      path_output = path_output,
      list_theme = list_theme_test,
      renderer = "renderer@1.0.0",
      path_npx = ""
    ),
    regexp = "path_npx"
  )

  testthat::expect_error(
    render_schema_diagram(
      text_dbml = "Table A {\n  a_id INTEGER [pk]\n}\n",
      path_output = path_output,
      list_theme = list_theme_test,
      renderer = "renderer@1.0.0",
      path_npx = "npx",
      data_table_colors = "A"
    ),
    regexp = "NULL or a data frame"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("render_schema_diagram() writes the themed diagram", {
  dir_test <-
    withr::local_tempdir()

  # One table in the attributes dbml-renderer 1.0.31 writes
  path_fixture <-
    base::file.path(dir_test, "fixture.svg")

  readr::write_file(
    x = stringr::str_c(
      "<svg>\n",
      "<g id=\"Alpha\" class=\"node\">\n<title>Alpha</title>\n",
      "<polygon fill=\"#1d71b8\" stroke=\"transparent\"/>\n",
      "<text font-family=\"Helvetica,sans-Serif\" fill=\"#ffffff\">",
      "Alpha</text>\n",
      "<polygon fill=\"#e7e2dd\" stroke=\"transparent\"/>\n",
      "<polygon fill=\"none\" stroke=\"#29235c\"/>\n",
      "<text font-family=\"Helvetica,sans-Serif\" fill=\"#29235c\">",
      "alpha_id</text>\n",
      "</g>\n",
      "</svg>\n"
    ),
    file = path_fixture
  )

  # A stand-in for npx that writes the fixture to the path given after
  #   --output, the sixth argument
  path_npx_fake <-
    if (
      .Platform$OS.type == "windows"
    ) {
      base::file.path(dir_test, "npx_fake.cmd")
    } else {
      base::file.path(dir_test, "npx_fake.sh")
    }

  if (
    .Platform$OS.type == "windows"
  ) {
    base::writeLines(
      text = stringr::str_c(
        "@type \"",
        base::normalizePath(path_fixture, winslash = "\\"),
        "\" > %6"
      ),
      con = path_npx_fake
    )
  } else {
    base::writeLines(
      text = c(
        "#!/bin/sh",
        stringr::str_c("cat '", path_fixture, "' > \"$6\"")
      ),
      con = path_npx_fake
    )

    base::Sys.chmod(path_npx_fake, mode = "0755")
  }

  path_output <-
    base::file.path(dir_test, "out", "diagram.svg")

  res <-
    render_schema_diagram(
      text_dbml = "Table Alpha {\n  alpha_id INTEGER [pk]\n}\n",
      path_output = path_output,
      list_theme = list_theme_test,
      renderer = "renderer@1.0.0",
      path_npx = path_npx_fake
    )

  testthat::expect_equal(res, path_output)

  text_res <-
    readr::read_file(path_output)

  testthat::expect_true(
    stringr::str_detect(text_res, stringr::fixed("fill=\"#8a554e\""))
  )

  testthat::expect_true(
    stringr::str_detect(
      text_res,
      stringr::fixed("font-family=\"Inter, Helvetica, sans-serif\"")
    )
  )

  testthat::expect_false(stringr::str_detect(text_res, "1d71b8"))

  render_schema_diagram(
    text_dbml = "Table Alpha {\n  alpha_id INTEGER [pk]\n}\n",
    path_output = path_output,
    list_theme = list_theme_test,
    renderer = "renderer@1.0.0",
    path_npx = path_npx_fake,
    data_table_colors = tibble::tibble(
      table_name = "Alpha", fill = "#156064", text = "#ffffff"
    )
  )

  text_res_sections <-
    readr::read_file(path_output)

  testthat::expect_true(
    stringr::str_detect(
      text_res_sections,
      stringr::fixed("fill=\"#156064\"")
    )
  )

  testthat::expect_false(stringr::str_detect(text_res_sections, "8a554e"))
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("render_schema_diagram() stops when the renderer fails", {
  path_output <-
    base::file.path(withr::local_tempdir(), "diagram.svg")

  # A command that cannot run stands in for a failing renderer
  testthat::expect_error(
    base::suppressWarnings(
      render_schema_diagram(
        text_dbml = "Table A {\n  a_id INTEGER [pk]\n}\n",
        path_output = path_output,
        list_theme = list_theme_test,
        renderer = "renderer@1.0.0",
        path_npx = base::file.path(withr::local_tempdir(), "missing_npx")
      )
    ),
    regexp = "dbml-renderer"
  )

  testthat::expect_false(base::file.exists(path_output))
})

testthat::test_that("render_schema_diagram() keeps an existing file", {
  path_output <-
    base::file.path(withr::local_tempdir(), "diagram.svg")

  base::writeLines(text = "<svg>old</svg>", con = path_output)

  testthat::expect_error(
    base::suppressWarnings(
      render_schema_diagram(
        text_dbml = "Table A {\n  a_id INTEGER [pk]\n}\n",
        path_output = path_output,
        list_theme = list_theme_test,
        renderer = "renderer@1.0.0",
        path_npx = base::file.path(withr::local_tempdir(), "missing_npx")
      )
    ),
    regexp = "dbml-renderer"
  )

  testthat::expect_equal(base::readLines(path_output), "<svg>old</svg>")
})
