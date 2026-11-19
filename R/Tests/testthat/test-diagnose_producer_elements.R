list_element_levels <-
  base::list(
    class = "data.frame",
    nullable = FALSE,
    min_rows = 1L,
    keys = base::list("sample_id"),
    columns = base::list(
      base::list(
        name = "sample_id",
        class = "character",
        nullable = FALSE,
        description = "Sample.",
        evidence = "e"
      ),
      base::list(
        name = "age",
        class = "numeric",
        nullable = FALSE,
        description = "Age.",
        evidence = "e"
      )
    )
  )

list_element_counts <-
  base::list(
    class = "data.frame",
    nullable = FALSE,
    columns = base::list(
      base::list(
        name = "sample_id",
        class = "character",
        nullable = FALSE,
        description = "Sample.",
        evidence = "e"
      )
    ),
    other_columns = base::list(
      class = "numeric",
      nullable = TRUE,
      description = "Taxon counts.",
      checks = base::list(range = base::list(min = 0)),
      forbidden_names = c("age", "dataset_id")
    )
  )

list_element_matrix <-
  base::list(
    class = "matrix",
    nullable = FALSE,
    value_class = "numeric",
    require_column_names = TRUE,
    min_rows = 2L,
    checks = base::list(whole_number = TRUE)
  )

list_levels_valid <-
  base::list(
    tibble::tibble(sample_id = c("s1", "s2"), age = c(-50, 120)),
    tibble::tibble(sample_id = "s1", age = 3000)
  )

mat_valid <-
  base::matrix(
    data = 1:4,
    nrow = 2,
    dimnames = base::list(NULL, c("s1", "s2"))
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_elements() passes valid elements", {
  res <-
    diagnose_producer_elements(
      list_values = list_levels_valid,
      list_element = list_element_levels,
      contract_id = "test_fossilpol",
      column = "levels",
      file_name = "a.qs"
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_equal(base::nrow(res), 0L)

  res_matrix <-
    diagnose_producer_elements(
      list_values = base::list(mat_valid, mat_valid),
      list_element = list_element_matrix,
      contract_id = "test_uncertainty",
      column = "age_uncertainty"
    )

  testthat::expect_equal(base::nrow(res_matrix), 0L)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_elements() flags missing elements", {
  res <-
    diagnose_producer_elements(
      list_values = c(list_levels_valid, base::list(NULL, NA)),
      list_element = list_element_levels,
      contract_id = "c",
      column = "levels"
    )

  testthat::expect_equal(dplyr::pull(res, check), "element_missing")

  testthat::expect_equal(dplyr::pull(res, n_violations), 2L)

  testthat::expect_equal(dplyr::pull(res, column), "levels[]")

  res_nullable <-
    diagnose_producer_elements(
      list_values = c(list_levels_valid, base::list(NULL)),
      list_element = purrr::list_modify(list_element_levels, nullable = TRUE),
      contract_id = "c",
      column = "levels"
    )

  testthat::expect_equal(base::nrow(res_nullable), 0L)
})

testthat::test_that("diagnose_producer_elements() flags wrong element class", {
  res <-
    diagnose_producer_elements(
      list_values = c(list_levels_valid, base::list("not a frame")),
      list_element = list_element_levels,
      contract_id = "c",
      column = "levels"
    )

  testthat::expect_equal(dplyr::pull(res, check), "class_mismatch")

  testthat::expect_equal(dplyr::pull(res, column), "levels[]")

  testthat::expect_equal(dplyr::pull(res, n_violations), 1L)
})

testthat::test_that("diagnose_producer_elements() checks nested columns", {
  list_levels_bad <-
    base::list(
      tibble::tibble(sample_id = c("s1", "s2"), age = c(10, NA)),
      tibble::tibble(sample_id = "s1"),
      tibble::tibble(sample_id = "s1", age = "old")
    )

  res <-
    diagnose_producer_elements(
      list_values = list_levels_bad,
      list_element = list_element_levels,
      contract_id = "test_fossilpol",
      column = "levels"
    )

  data_missing <-
    res |>
    dplyr::filter(check == "column_missing")

  testthat::expect_equal(dplyr::pull(data_missing, column), "levels[].age")

  testthat::expect_equal(dplyr::pull(data_missing, n_violations), 1L)

  data_class <-
    res |>
    dplyr::filter(check == "class_mismatch")

  testthat::expect_equal(dplyr::pull(data_class, column), "levels[].age")

  data_value <-
    res |>
    dplyr::filter(check == "value_missing")

  testthat::expect_equal(dplyr::pull(data_value, column), "levels[].age")

  testthat::expect_equal(dplyr::pull(data_value, n_violations), 1L)
})

testthat::test_that("diagnose_producer_elements() checks keys and rows", {
  list_levels_bad <-
    base::list(
      tibble::tibble(sample_id = c("s1", "s1"), age = c(10, 20)),
      tibble::tibble(sample_id = base::character(0), age = base::numeric(0))
    )

  res <-
    diagnose_producer_elements(
      list_values = list_levels_bad,
      list_element = list_element_levels,
      contract_id = "c",
      column = "levels"
    )

  testthat::expect_setequal(
    dplyr::pull(res, check),
    c("key_duplicate", "element_rows")
  )
})

testthat::test_that("diagnose_producer_elements() applies other_columns", {
  list_counts <-
    base::list(
      tibble::tibble(sample_id = "s1", Pinus = 3, Betula = -1),
      tibble::tibble(sample_id = "s1", age = 5),
      tibble::tibble(sample_id = "s1", Alnus = "many")
    )

  res <-
    diagnose_producer_elements(
      list_values = list_counts,
      list_element = list_element_counts,
      contract_id = "c",
      column = "counts_harmonised"
    )

  testthat::expect_setequal(
    dplyr::pull(res, check),
    c("column_forbidden", "class_mismatch", "value_out_of_range")
  )

  testthat::expect_true(
    base::all(
      stringr::str_detect(dplyr::pull(res, column), "^counts_harmonised\\[\\]")
    )
  )
})

testthat::test_that("diagnose_producer_elements() flags extra columns", {
  list_element_strict <-
    purrr::list_modify(list_element_levels, extra_columns = "error")

  res <-
    diagnose_producer_elements(
      list_values = base::list(
        tibble::tibble(sample_id = "s1", age = 1, depth = 10)
      ),
      list_element = list_element_strict,
      contract_id = "c",
      column = "levels"
    )

  testthat::expect_equal(dplyr::pull(res, check), "column_extra")

  testthat::expect_match(dplyr::pull(res, message), "depth")
})

testthat::test_that("diagnose_producer_elements() checks matrices", {
  mat_no_names <-
    base::matrix(data = 1:4, nrow = 2)

  mat_missing <-
    base::matrix(
      data = c(1, NA, 3, 4.5),
      nrow = 2,
      dimnames = base::list(NULL, c("s1", "s2"))
    )

  mat_text <-
    base::matrix(
      data = c("a", "b", "c", "d"),
      nrow = 2,
      dimnames = base::list(NULL, c("s1", "s2"))
    )

  res <-
    diagnose_producer_elements(
      list_values = base::list(mat_no_names, mat_missing, mat_text),
      list_element = list_element_matrix,
      contract_id = "c",
      column = "age_uncertainty"
    )

  testthat::expect_setequal(
    dplyr::pull(res, check),
    c(
      "element_column_names", "value_missing", "value_not_whole",
      "class_mismatch"
    )
  )
})

testthat::test_that("diagnose_producer_elements() checks atomic elements", {
  list_element_text <-
    base::list(
      class = "character",
      nullable = FALSE,
      checks = base::list(not_empty = TRUE)
    )

  res <-
    diagnose_producer_elements(
      list_values = base::list(c("a", "b"), c("", NA)),
      list_element = list_element_text,
      contract_id = "c",
      column = "methodology_reference"
    )

  testthat::expect_setequal(
    dplyr::pull(res, check),
    c("value_missing", "value_empty")
  )
})

testthat::test_that("diagnose_producer_elements() recurses into list columns", {
  list_element_outer <-
    base::list(
      class = "data.frame",
      nullable = FALSE,
      columns = base::list(
        base::list(
          name = "references",
          class = "list",
          nullable = FALSE,
          description = "d",
          evidence = "e",
          element = base::list(class = "character", nullable = FALSE)
        )
      )
    )

  res <-
    diagnose_producer_elements(
      list_values = base::list(
        tibble::tibble(references = base::list("a", NA_character_))
      ),
      list_element = list_element_outer,
      contract_id = "c",
      column = "plots"
    )

  testthat::expect_equal(dplyr::pull(res, check), "element_missing")

  testthat::expect_equal(dplyr::pull(res, column), "plots[].references[]")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_elements() validates arguments", {
  testthat::expect_error(
    diagnose_producer_elements(
      list_values = "not a list",
      list_element = list_element_levels,
      contract_id = "c",
      column = "levels"
    ),
    regexp = "list_values"
  )

  testthat::expect_error(
    diagnose_producer_elements(
      list_values = list_levels_valid,
      list_element = list_element_levels,
      contract_id = "c",
      column = c("a", "b")
    ),
    regexp = "column"
  )
})


#----------------------------------------------------------#
# All-missing nested columns and duplicated names -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_elements() accepts all-NA nullables", {
  list_element_depth <-
    purrr::assign_in(
      list_element_levels,
      where = base::list("columns", 3),
      value = base::list(
        name = "depth",
        class = "numeric",
        nullable = TRUE,
        description = "Depth.",
        evidence = "e"
      )
    )

  res <-
    diagnose_producer_elements(
      list_values = base::list(
        tibble::tibble(sample_id = "s1", age = 1, depth = NA),
        tibble::tibble(sample_id = "s1", age = 2, depth = 3.5)
      ),
      list_element = list_element_depth,
      contract_id = "c",
      column = "levels"
    )

  testthat::expect_equal(base::nrow(res), 0L)
})

testthat::test_that("diagnose_producer_elements() flags duplicated names", {
  data_duplicated <-
    base::data.frame(
      sample_id = "s1",
      Pinus = 1,
      Pinus = 2,
      check.names = FALSE
    )

  res <-
    diagnose_producer_elements(
      list_values = base::list(data_duplicated),
      list_element = list_element_counts,
      contract_id = "c",
      column = "counts_harmonised"
    )

  testthat::expect_equal(dplyr::pull(res, check), "column_duplicate")

  testthat::expect_equal(dplyr::pull(res, column), "counts_harmonised[]")
})
