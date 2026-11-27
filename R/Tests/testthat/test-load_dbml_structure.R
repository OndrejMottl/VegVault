#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_dbml_structure() validates its argument", {
  testthat::expect_error(
    load_dbml_structure(path_dbml = 1),
    regexp = "path_dbml"
  )

  testthat::expect_error(
    load_dbml_structure(
      path_dbml = base::file.path(withr::local_tempdir(), "missing.dbml")
    ),
    regexp = "path_dbml"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("load_dbml_structure() reads tables and references", {
  path_dbml <-
    withr::local_tempfile(fileext = ".dbml")

  base::writeLines(
    text = c(
      "// A comment line",
      "Project Example {",
      "  database_type: 'SQLite'",
      "  Note: '''",
      "    Table NotATable {",
      "  '''",
      "}",
      "",
      "Table Alpha {",
      "  alpha_id INTEGER [pk]",
      "  alpha_name TEXT [not null, unique, note: 'a name, unique']",
      "  created TEXT [default: `CURRENT_DATE`] // when",
      "  Note: 'One row per alpha'",
      "}",
      "",
      "table Beta [note: 'a link table'] {",
      "  alpha_id INTEGER [not null]",
      "  gamma_id INTEGER [not null]",
      "  value REAL",
      "",
      "  indexes {",
      "    (alpha_id, gamma_id) [pk]",
      "    value [name: 'idx_beta_value']",
      "  }",
      "}",
      "",
      "Table Gamma {",
      "  gamma_id INTEGER [primary key]",
      "}",
      "",
      "Ref: Beta.alpha_id > Alpha.alpha_id",
      "Ref: Gamma.gamma_id < Beta.gamma_id"
    ),
    con = path_dbml
  )

  res <-
    load_dbml_structure(path_dbml = path_dbml)

  testthat::expect_type(res, "list")

  testthat::expect_named(res, c("columns", "references"))

  testthat::expect_equal(
    res[["columns"]],
    tibble::tibble(
      table_name = c(
        "Alpha", "Alpha", "Alpha", "Beta", "Beta", "Beta", "Gamma"
      ),
      column_name = c(
        "alpha_id", "alpha_name", "created", "alpha_id", "gamma_id",
        "value", "gamma_id"
      ),
      column_type = c(
        "INTEGER", "TEXT", "TEXT", "INTEGER", "INTEGER", "REAL", "INTEGER"
      ),
      flag_primary_key = c(
        TRUE, FALSE, FALSE, TRUE, TRUE, FALSE, TRUE
      ),
      flag_not_null = c(
        FALSE, TRUE, FALSE, TRUE, TRUE, FALSE, FALSE
      )
    )
  )

  testthat::expect_equal(
    res[["references"]],
    tibble::tibble(
      table_name = c("Beta", "Beta"),
      column_name = c("alpha_id", "gamma_id"),
      ref_table_name = c("Alpha", "Gamma"),
      ref_column_name = c("alpha_id", "gamma_id")
    )
  )
})

testthat::test_that("load_dbml_structure() reads the project diagram", {
  res <-
    load_dbml_structure(
      path_dbml = here::here("Data", "SQL", "database_structure.dbml")
    )

  testthat::expect_equal(
    base::length(base::unique(dplyr::pull(res[["columns"]], table_name))),
    34L
  )

  testthat::expect_true(base::nrow(res[["references"]]) > 0L)
})


#----------------------------------------------------------#
# Errors -----
#----------------------------------------------------------#

testthat::test_that("load_dbml_structure() aborts on unknown lines", {
  path_dbml <-
    withr::local_tempfile(fileext = ".dbml")

  base::writeLines(
    text = c(
      "Table Alpha {",
      "  alpha_id INTEGER [pk]",
      "  this is not a column",
      "}"
    ),
    con = path_dbml
  )

  testthat::expect_error(
    load_dbml_structure(path_dbml = path_dbml),
    regexp = "this is not a column"
  )

  path_dbml_ref <-
    withr::local_tempfile(fileext = ".dbml")

  base::writeLines(
    text = c(
      "Table Alpha {",
      "  alpha_id INTEGER [pk]",
      "}",
      "Ref: Alpha.alpha_id >"
    ),
    con = path_dbml_ref
  )

  testthat::expect_error(
    load_dbml_structure(path_dbml = path_dbml_ref),
    regexp = "Ref"
  )
})

testthat::test_that("load_dbml_structure() aborts on broken structure", {
  path_unclosed <-
    withr::local_tempfile(fileext = ".dbml")

  base::writeLines(
    text = c("Table Alpha {", "  alpha_id INTEGER [pk]"),
    con = path_unclosed
  )

  testthat::expect_error(
    load_dbml_structure(path_dbml = path_unclosed),
    regexp = "not closed"
  )

  path_twice <-
    withr::local_tempfile(fileext = ".dbml")

  base::writeLines(
    text = c(
      "Table Alpha {", "  alpha_id INTEGER", "}",
      "Table Alpha {", "  alpha_id INTEGER", "}"
    ),
    con = path_twice
  )

  testthat::expect_error(
    load_dbml_structure(path_dbml = path_twice),
    regexp = "Alpha"
  )

  path_no_tables <-
    withr::local_tempfile(fileext = ".dbml")

  base::writeLines(
    text = c("Project Example {", "  database_type: 'SQLite'", "}"),
    con = path_no_tables
  )

  testthat::expect_error(
    load_dbml_structure(path_dbml = path_no_tables),
    regexp = "no table"
  )
})
