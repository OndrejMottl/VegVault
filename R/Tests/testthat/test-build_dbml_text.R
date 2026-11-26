# Alpha <- Beta <- Gamma -> Delta; Gamma has a primary key of two columns
list_structure_dbml <-
  base::list(
    columns = tibble::tibble(
      table_name = c(
        "Alpha", "Alpha", "Beta", "Beta", "Beta", "Gamma", "Gamma", "Delta"
      ),
      column_name = c(
        "alpha_id", "alpha_name", "beta_id", "alpha_id", "value", "beta_id",
        "delta_id", "delta_id"
      ),
      column_type = c(
        "INTEGER", "TEXT", "INTEGER", "INTEGER", "REAL", "INTEGER",
        "INTEGER", "INTEGER"
      ),
      flag_primary_key = c(TRUE, FALSE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE),
      flag_not_null = c(FALSE, TRUE, FALSE, FALSE, FALSE, TRUE, TRUE, TRUE)
    ),
    references = tibble::tibble(
      table_name = c("Beta", "Gamma", "Gamma"),
      column_name = c("alpha_id", "beta_id", "delta_id"),
      ref_table_name = c("Alpha", "Beta", "Delta"),
      ref_column_name = c("alpha_id", "beta_id", "delta_id")
    )
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_dbml_text() writes tables and their references", {
  res <-
    build_dbml_text(
      list_dbml_structure = list_structure_dbml,
      vec_tables = c("Alpha", "Beta")
    )

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 1L)

  testthat::expect_equal(
    res,
    stringr::str_c(
      "Table Alpha {\n",
      "  alpha_id INTEGER [pk]\n",
      "  alpha_name TEXT [not null]\n",
      "}\n",
      "\n",
      "Table Beta {\n",
      "  beta_id INTEGER [pk]\n",
      "  alpha_id INTEGER\n",
      "  value REAL\n",
      "}\n",
      "\n",
      "Ref: Beta.alpha_id > Alpha.alpha_id\n"
    )
  )
})

testthat::test_that("build_dbml_text() writes a key of several columns", {
  res <-
    build_dbml_text(
      list_dbml_structure = list_structure_dbml,
      vec_tables = c("Gamma", "Delta")
    )

  testthat::expect_equal(
    res,
    stringr::str_c(
      "Table Gamma {\n",
      "  beta_id INTEGER [not null]\n",
      "  delta_id INTEGER [not null]\n",
      "  indexes {\n",
      "    (beta_id, delta_id) [pk]\n",
      "  }\n",
      "}\n",
      "\n",
      "Table Delta {\n",
      "  delta_id INTEGER [pk, not null]\n",
      "}\n",
      "\n",
      "Ref: Gamma.delta_id > Delta.delta_id\n"
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("build_dbml_text() leaves out links to other tables", {
  res <-
    build_dbml_text(
      list_dbml_structure = list_structure_dbml,
      vec_tables = "Beta"
    )

  testthat::expect_equal(
    res,
    stringr::str_c(
      "Table Beta {\n",
      "  beta_id INTEGER [pk]\n",
      "  alpha_id INTEGER\n",
      "  value REAL\n",
      "}\n"
    )
  )
})

testthat::test_that("build_dbml_text() reads back as the same structure", {
  path_dbml <-
    withr::local_tempfile(fileext = ".dbml")

  base::writeLines(
    text = build_dbml_text(
      list_dbml_structure = list_structure_dbml,
      vec_tables = c("Alpha", "Beta", "Gamma", "Delta")
    ),
    con = path_dbml,
    sep = ""
  )

  res <-
    load_dbml_structure(path_dbml = path_dbml)

  testthat::expect_equal(res, list_structure_dbml)
})

testthat::test_that("build_dbml_text() reads back the project schema", {
  list_structure_project <-
    load_dbml_structure(
      path_dbml = here::here("Data", "SQL", "database_structure.dbml")
    )

  vec_tables_project <-
    list_structure_project |>
    purrr::chuck("columns") |>
    dplyr::pull(table_name) |>
    base::unique()

  path_dbml <-
    withr::local_tempfile(fileext = ".dbml")

  base::writeLines(
    text = build_dbml_text(
      list_dbml_structure = list_structure_project,
      vec_tables = vec_tables_project
    ),
    con = path_dbml,
    sep = ""
  )

  res <-
    load_dbml_structure(path_dbml = path_dbml)

  testthat::expect_equal(res, list_structure_project)
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_dbml_text() refuses unknown tables", {
  testthat::expect_error(
    build_dbml_text(
      list_dbml_structure = list_structure_dbml,
      vec_tables = c("Alpha", "Omega")
    ),
    regexp = "Omega"
  )
})

testthat::test_that("build_dbml_text() validates the table names", {
  testthat::expect_error(
    build_dbml_text(
      list_dbml_structure = list_structure_dbml,
      vec_tables = base::character(0)
    ),
    regexp = "vec_tables"
  )

  testthat::expect_error(
    build_dbml_text(
      list_dbml_structure = list_structure_dbml,
      vec_tables = c("Alpha", "Alpha")
    ),
    regexp = "vec_tables"
  )

  testthat::expect_error(
    build_dbml_text(
      list_dbml_structure = list_structure_dbml,
      vec_tables = c("Alpha", NA)
    ),
    regexp = "vec_tables"
  )
})
