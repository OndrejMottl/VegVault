list_element_frame <-
  base::list(
    class = "data.frame",
    nullable = FALSE,
    min_rows = 1L,
    extra_columns = "error",
    keys = base::list("sample_id"),
    columns = base::list(
      base::list(
        name = "sample_id",
        class = "character",
        nullable = FALSE,
        description = "Sample identifier.",
        evidence = "x"
      )
    ),
    other_columns = base::list(
      class = "numeric",
      nullable = TRUE,
      description = "One column per taxon.",
      forbidden_names = c("age", "sample_name")
    )
  )

list_element_matrix <-
  base::list(
    class = "matrix",
    nullable = FALSE,
    value_class = "numeric",
    require_column_names = TRUE,
    min_rows = 1L,
    checks = base::list(finite = TRUE)
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_element_spec() accepts valid entries", {
  res_frame <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = list_element_frame,
      field_path = "columns[1].element"
    )

  testthat::expect_type(res_frame, "character")

  testthat::expect_length(res_frame, 0L)

  res_matrix <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = list_element_matrix,
      field_path = "columns[1].element"
    )

  testthat::expect_length(res_matrix, 0L)

  res_atomic <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = base::list(class = "character", nullable = TRUE),
      field_path = "columns[1].element"
    )

  testthat::expect_length(res_atomic, 0L)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_element_spec() checks class, nullable", {
  res_list <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = base::list(class = "list", nullable = TRUE),
      field_path = "columns[2].element"
    )

  testthat::expect_length(res_list, 1L)

  testthat::expect_match(res_list, "^columns\\[2\\]\\.element")

  res_missing <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = base::list(class = "character"),
      field_path = "e"
    )

  testthat::expect_length(res_missing, 1L)

  testthat::expect_match(res_missing, "nullable")
})

testthat::test_that("diagnose_producer_element_spec() limits fields by class", {
  res_matrix <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = purrr::list_modify(
        list_element_matrix,
        keys = base::list("a")
      ),
      field_path = "e"
    )

  testthat::expect_length(res_matrix, 1L)

  testthat::expect_match(res_matrix, "keys")

  res_atomic <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = base::list(
        class = "character",
        nullable = TRUE,
        min_rows = 1L
      ),
      field_path = "e"
    )

  testthat::expect_length(res_atomic, 1L)

  testthat::expect_match(res_atomic, "min_rows")
})

testthat::test_that("diagnose_producer_element_spec() checks frame fields", {
  res_keys <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = purrr::list_modify(
        list_element_frame,
        keys = base::list("age")
      ),
      field_path = "e"
    )

  testthat::expect_length(res_keys, 1L)

  testthat::expect_match(res_keys, "age")

  res_rows <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = purrr::list_modify(list_element_frame, min_rows = -1),
      field_path = "e"
    )

  testthat::expect_length(res_rows, 1L)

  testthat::expect_match(res_rows, "min_rows")

  res_other <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = purrr::assign_in(
        list_element_frame,
        where = c("other_columns", "description"),
        value = rlang::zap()
      ),
      field_path = "e"
    )

  testthat::expect_length(res_other, 1L)

  testthat::expect_match(res_other, "other_columns")
})

testthat::test_that("diagnose_producer_element_spec() recurses into columns", {
  res <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = purrr::assign_in(
        list_element_frame,
        where = base::list("columns", 1, "nullable"),
        value = "no"
      ),
      field_path = "columns[3].element"
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(res, "^columns\\[3\\]\\.element\\.columns\\[1\\]")
})

testthat::test_that("diagnose_producer_element_spec() checks matrix fields", {
  res <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = purrr::list_modify(
        list_element_matrix,
        value_class = "data.frame",
        require_column_names = "yes"
      ),
      field_path = "e"
    )

  testthat::expect_length(res, 2L)

  testthat::expect_true(base::any(stringr::str_detect(res, "value_class")))

  testthat::expect_true(
    base::any(stringr::str_detect(res, "require_column_names"))
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_element_spec() needs a map", {
  res <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = "data.frame",
      field_path = "columns[1].element"
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(res, "^columns\\[1\\]\\.element")

  testthat::expect_error(
    diagnose_producer_element_spec(
      fn_diagnose_columns = diagnose_producer_column_specs,
      list_element = list_element_frame,
      field_path = NA_character_
    ),
    regexp = "field_path"
  )
})


#----------------------------------------------------------#
# Column checker -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_element_spec() uses the checker", {
  res <-
    diagnose_producer_element_spec(
      fn_diagnose_columns = function(list_columns, field_path) {
        stringr::str_c(field_path, ": checked by the given function")
      },
      list_element = list(
        class = "data.frame",
        nullable = FALSE,
        columns = list(
          list(name = "depth", class = "numeric", nullable = FALSE)
        )
      ),
      field_path = "columns[1].element"
    )

  testthat::expect_equal(
    res,
    "columns[1].element.columns: checked by the given function"
  )
})

testthat::test_that("diagnose_producer_element_spec() needs a checker", {
  testthat::expect_error(
    diagnose_producer_element_spec(
      fn_diagnose_columns = "diagnose_producer_column_specs",
      list_element = list(class = "numeric", nullable = FALSE),
      field_path = "columns[1].element"
    ),
    regexp = "fn_diagnose_columns"
  )
})

testthat::test_that("diagnose_producer_element_spec() names no checker", {
  # {targets} reads two functions that call each other by name as a cycle
  #   and refuses every pipeline that loads them
  vec_dependencies <-
    targets::tar_deps_raw(diagnose_producer_element_spec)

  testthat::expect_false(
    "diagnose_producer_column_specs" %in% vec_dependencies
  )
})
