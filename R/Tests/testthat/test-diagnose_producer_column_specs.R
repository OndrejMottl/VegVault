list_column_id <-
  base::list(
    name = "dataset_id",
    class = "numeric",
    nullable = FALSE,
    description = "Dataset identifier.",
    evidence = "03_Import_fossilpol_data.R"
  )

list_column_levels <-
  base::list(
    name = "levels",
    class = "list",
    nullable = FALSE,
    description = "Levels of each dataset.",
    evidence = "03_Import_fossilpol_data.R",
    element = base::list(
      class = "data.frame",
      nullable = FALSE,
      min_rows = 1L,
      extra_columns = "allow",
      keys = base::list("sample_id"),
      columns = base::list(
        base::list(
          name = "sample_id",
          class = "character",
          nullable = FALSE,
          description = "Sample identifier.",
          evidence = "x"
        ),
        base::list(
          name = "age",
          class = "numeric",
          nullable = FALSE,
          unit = "cal yr BP",
          description = "Sample age.",
          evidence = "x",
          checks = base::list(finite = TRUE)
        )
      )
    )
  )

list_column_counts <-
  base::list(
    name = "counts_harmonised",
    class = "list",
    nullable = FALSE,
    description = "Counts.",
    evidence = "x",
    element = base::list(
      class = "data.frame",
      nullable = FALSE,
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
        checks = base::list(range = base::list(min = 0)),
        forbidden_names = c("age", "dataset_name")
      )
    )
  )

list_column_uncertainty <-
  base::list(
    name = "age_uncertainty",
    class = "list",
    nullable = FALSE,
    description = "Age iterations.",
    evidence = "x",
    element = base::list(
      class = "matrix",
      nullable = FALSE,
      value_class = "numeric",
      require_column_names = TRUE,
      checks = base::list(finite = TRUE)
    )
  )

list_column_references <-
  base::list(
    name = "methodology_reference",
    class = "list",
    nullable = TRUE,
    description = "References.",
    evidence = "x",
    element = base::list(
      class = "character",
      nullable = TRUE
    )
  )


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_column_specs() accepts valid specs", {
  res <-
    diagnose_producer_column_specs(
      list_columns = base::list(
        list_column_id,
        list_column_levels,
        list_column_counts,
        list_column_uncertainty,
        list_column_references
      ),
      field_path = "columns"
    )

  testthat::expect_type(res, "character")

  testthat::expect_length(res, 0L)
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_column_specs() flags missing fields", {
  list_column_bad <-
    purrr::list_modify(
      list_column_id,
      name = "dataset_name",
      evidence = rlang::zap()
    )

  res <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_id, list_column_bad),
      field_path = "columns"
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(res, "^columns\\[2\\]")

  testthat::expect_match(res, "evidence")
})

testthat::test_that("diagnose_producer_column_specs() flags unknown fields", {
  list_column_bad <-
    purrr::list_modify(
      list_column_id,
      nulable = TRUE
    )

  res <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_bad),
      field_path = "columns"
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(res, "nulable")
})

testthat::test_that("diagnose_producer_column_specs() flags bad values", {
  list_column_class <-
    purrr::list_modify(
      list_column_id,
      class = "numerik"
    )

  res_class <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_class),
      field_path = "columns"
    )

  testthat::expect_length(res_class, 1L)

  testthat::expect_match(res_class, "numerik")

  list_column_nullable <-
    purrr::list_modify(
      list_column_id,
      nullable = "no"
    )

  res_nullable <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_nullable),
      field_path = "columns"
    )

  testthat::expect_length(res_nullable, 1L)

  testthat::expect_match(res_nullable, "nullable")
})

testthat::test_that("diagnose_producer_column_specs() flags duplicate names", {
  res <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_id, list_column_id),
      field_path = "columns"
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(res, "dataset_id")
})

testthat::test_that("diagnose_producer_column_specs() pairs list, element", {
  list_column_no_element <-
    purrr::list_modify(
      list_column_references,
      element = rlang::zap()
    )

  res_missing <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_no_element),
      field_path = "columns"
    )

  testthat::expect_length(res_missing, 1L)

  testthat::expect_match(res_missing, "element")

  list_column_extra_element <-
    purrr::list_modify(
      list_column_id,
      element = base::list(class = "character", nullable = FALSE)
    )

  res_extra <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_extra_element),
      field_path = "columns"
    )

  testthat::expect_length(res_extra, 1L)

  testthat::expect_match(res_extra, "element")
})

testthat::test_that("diagnose_producer_column_specs() recurses into nesting", {
  list_column_bad <-
    purrr::assign_in(
      list_column_levels,
      where = base::list("element", "columns", 2, "class"),
      value = "numerik"
    )

  res <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_bad),
      field_path = "columns"
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(
    res,
    "^columns\\[1\\]\\.element\\.columns\\[2\\]"
  )
})

testthat::test_that("diagnose_producer_column_specs() checks element fields", {
  list_column_key <-
    purrr::assign_in(
      list_column_levels,
      where = c("element", "keys"),
      value = base::list("sample_name")
    )

  res_key <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_key),
      field_path = "columns"
    )

  testthat::expect_length(res_key, 1L)

  testthat::expect_match(res_key, "sample_name")

  list_column_extra <-
    purrr::assign_in(
      list_column_levels,
      where = c("element", "extra_columns"),
      value = "warn"
    )

  res_extra <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_extra),
      field_path = "columns"
    )

  testthat::expect_length(res_extra, 1L)

  testthat::expect_match(res_extra, "extra_columns")

  list_column_matrix <-
    purrr::assign_in(
      list_column_uncertainty,
      where = c("element", "columns"),
      value = base::list(list_column_id)
    )

  res_matrix <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_matrix),
      field_path = "columns"
    )

  testthat::expect_length(res_matrix, 1L)

  testthat::expect_match(res_matrix, "columns")
})

testthat::test_that("diagnose_producer_column_specs() checks other_columns", {
  list_column_bad <-
    purrr::assign_in(
      list_column_counts,
      where = c("element", "other_columns", "class"),
      value = "list"
    )

  res <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_bad),
      field_path = "columns"
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(res, "other_columns")
})

testthat::test_that("diagnose_producer_column_specs() passes on checks", {
  list_column_bad <-
    purrr::list_modify(
      list_column_id,
      checks = base::list(maximum = 1)
    )

  res <-
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_bad),
      field_path = "columns"
    )

  testthat::expect_length(res, 1L)

  testthat::expect_match(res, "^columns\\[1\\]\\.checks")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_column_specs() needs a list", {
  res_empty <-
    diagnose_producer_column_specs(
      list_columns = base::list(),
      field_path = "columns"
    )

  testthat::expect_length(res_empty, 1L)

  testthat::expect_match(res_empty, "columns")

  testthat::expect_error(
    diagnose_producer_column_specs(
      list_columns = base::list(list_column_id),
      field_path = c("a", "b")
    ),
    regexp = "field_path"
  )
})


#----------------------------------------------------------#
# Pipeline use -----
#----------------------------------------------------------#

testthat::test_that("diagnose_producer_column_specs() never names itself", {
  # {targets} reads a function that calls itself by name as a cycle and
  #   refuses every pipeline that loads it
  vec_dependencies <-
    targets::tar_deps_raw(diagnose_producer_column_specs)

  testthat::expect_false(
    "diagnose_producer_column_specs" %in% vec_dependencies
  )
})
