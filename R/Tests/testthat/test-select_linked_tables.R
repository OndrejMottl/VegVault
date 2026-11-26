# Alpha <- Beta <- Gamma -> Delta, Lonely without links, Beta refers to
#   itself
list_structure_links <-
  base::list(
    columns = tibble::tibble(
      table_name = c(
        "Alpha", "Beta", "Beta", "Beta", "Gamma", "Gamma", "Delta", "Lonely"
      ),
      column_name = c(
        "alpha_id", "beta_id", "alpha_id", "parent_id", "beta_id",
        "delta_id", "delta_id", "lonely_id"
      ),
      column_type = "INTEGER",
      flag_primary_key = c(TRUE, TRUE, FALSE, FALSE, TRUE, TRUE, TRUE, TRUE),
      flag_not_null = FALSE
    ),
    references = tibble::tibble(
      table_name = c("Beta", "Beta", "Gamma", "Gamma"),
      column_name = c("alpha_id", "parent_id", "beta_id", "delta_id"),
      ref_table_name = c("Alpha", "Beta", "Beta", "Delta"),
      ref_column_name = c("alpha_id", "beta_id", "beta_id", "delta_id")
    )
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("select_linked_tables() adds the tables of both ends", {
  res <-
    select_linked_tables(
      list_dbml_structure = list_structure_links,
      vec_tables = "Beta"
    )

  testthat::expect_type(res, "character")

  testthat::expect_equal(res, c("Beta", "Alpha", "Gamma"))
})

testthat::test_that("select_linked_tables() keeps the given tables first", {
  res <-
    select_linked_tables(
      list_dbml_structure = list_structure_links,
      vec_tables = c("Delta", "Alpha")
    )

  testthat::expect_equal(res, c("Delta", "Alpha", "Beta", "Gamma"))
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("select_linked_tables() adds only direct links", {
  res <-
    select_linked_tables(
      list_dbml_structure = list_structure_links,
      vec_tables = "Alpha"
    )

  testthat::expect_equal(res, c("Alpha", "Beta"))
})

testthat::test_that("select_linked_tables() keeps a table without links", {
  res <-
    select_linked_tables(
      list_dbml_structure = list_structure_links,
      vec_tables = "Lonely"
    )

  testthat::expect_equal(res, "Lonely")
})

testthat::test_that("select_linked_tables() lists a linked table once", {
  res <-
    select_linked_tables(
      list_dbml_structure = list_structure_links,
      vec_tables = c("Beta", "Gamma")
    )

  testthat::expect_equal(res, c("Beta", "Gamma", "Alpha", "Delta"))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("select_linked_tables() refuses unknown tables", {
  testthat::expect_error(
    select_linked_tables(
      list_dbml_structure = list_structure_links,
      vec_tables = c("Beta", "Omega")
    ),
    regexp = "Omega"
  )
})

testthat::test_that("select_linked_tables() validates the table names", {
  testthat::expect_error(
    select_linked_tables(
      list_dbml_structure = list_structure_links,
      vec_tables = base::character(0)
    ),
    regexp = "vec_tables"
  )

  testthat::expect_error(
    select_linked_tables(
      list_dbml_structure = list_structure_links,
      vec_tables = c("Beta", NA)
    ),
    regexp = "vec_tables"
  )

  testthat::expect_error(
    select_linked_tables(
      list_dbml_structure = list_structure_links,
      vec_tables = c("Beta", "Beta")
    ),
    regexp = "vec_tables"
  )
})
