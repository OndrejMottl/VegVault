#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_table_ids() validates arguments", {
  data_table <-
    tibble::tibble(name = c("b", "a"))

  testthat::expect_error(
    prepare_table_ids(
      data_table = "not a table",
      vec_sort_columns = "name",
      name_id = "row_id",
      name_table = "Tbl"
    ),
    regexp = "data_table"
  )

  testthat::expect_error(
    prepare_table_ids(
      data_table = data_table,
      vec_sort_columns = base::character(0),
      name_id = "row_id",
      name_table = "Tbl"
    ),
    regexp = "vec_sort_columns"
  )

  testthat::expect_error(
    prepare_table_ids(
      data_table = data_table,
      vec_sort_columns = "missing_column",
      name_id = "row_id",
      name_table = "Tbl"
    ),
    regexp = "vec_sort_columns"
  )

  testthat::expect_error(
    prepare_table_ids(
      data_table = data_table,
      vec_sort_columns = "name",
      name_id = c("row_id", "other_id"),
      name_table = "Tbl"
    ),
    regexp = "name_id"
  )

  testthat::expect_error(
    prepare_table_ids(
      data_table = data_table,
      vec_sort_columns = "name",
      name_id = "name",
      name_table = "Tbl"
    ),
    regexp = "name_id"
  )

  testthat::expect_error(
    prepare_table_ids(
      data_table = data_table,
      vec_sort_columns = "name",
      name_id = "row_id",
      name_table = NA_character_
    ),
    regexp = "name_table"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_table_ids() numbers rows by the sorted key", {
  data_table <-
    tibble::tibble(
      block = c(2L, 1L, 1L),
      name = c("a", "c", "b"),
      value = c(10, 20, 30)
    )

  res <-
    prepare_table_ids(
      data_table = data_table,
      vec_sort_columns = c("block", "name"),
      name_id = "row_id",
      name_table = "Tbl"
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(res, c("row_id", "block", "name", "value"))
  testthat::expect_type(dplyr::pull(res, row_id), "integer")
  testthat::expect_equal(dplyr::pull(res, row_id), base::seq_len(3L))
  testthat::expect_equal(dplyr::pull(res, name), c("b", "c", "a"))
  testthat::expect_equal(dplyr::pull(res, value), c(30, 20, 10))
})

testthat::test_that("prepare_table_ids() returns an empty table unchanged", {
  res <-
    prepare_table_ids(
      data_table = tibble::tibble(name = base::character(0)),
      vec_sort_columns = "name",
      name_id = "row_id",
      name_table = "Tbl"
    )

  testthat::expect_equal(base::nrow(res), 0L)
  testthat::expect_named(res, c("row_id", "name"))
  testthat::expect_type(dplyr::pull(res, row_id), "integer")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_table_ids() gives ids whatever the row order", {
  base::set.seed(900723)

  data_table <-
    tibble::tibble(
      taxon_name = stringr::str_c("taxon_", base::seq_len(1000L)),
      value = stats::runif(n = 1000L)
    )

  data_shuffled <-
    dplyr::slice_sample(data_table, n = 1000L)

  res_ordered <-
    prepare_table_ids(
      data_table = data_table,
      vec_sort_columns = "taxon_name",
      name_id = "taxon_id",
      name_table = "Taxa"
    )

  res_shuffled <-
    prepare_table_ids(
      data_table = data_shuffled,
      vec_sort_columns = "taxon_name",
      name_id = "taxon_id",
      name_table = "Taxa"
    )

  testthat::expect_identical(res_shuffled, res_ordered)
  testthat::expect_equal(base::nrow(res_ordered), 1000L)
})

testthat::test_that("prepare_table_ids() sorts text in the C locale", {
  res <-
    prepare_table_ids(
      data_table = tibble::tibble(name = c("b", "a", "B", "\u00e9")),
      vec_sort_columns = "name",
      name_id = "row_id",
      name_table = "Tbl"
    )

  testthat::expect_equal(
    dplyr::pull(res, name),
    c("B", "a", "b", "\u00e9")
  )
})


#----------------------------------------------------------#
# Edge cases and errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_table_ids() refuses repeated keys", {
  data_table <-
    tibble::tibble(name = c("dup_key", "dup_key", "single_key"))

  testthat::expect_error(
    prepare_table_ids(
      data_table = data_table,
      vec_sort_columns = "name",
      name_id = "row_id",
      name_table = "Tbl"
    ),
    regexp = "Tbl"
  )

  testthat::expect_error(
    prepare_table_ids(
      data_table = data_table,
      vec_sort_columns = "name",
      name_id = "row_id",
      name_table = "Tbl"
    ),
    regexp = "dup_key"
  )
})

testthat::test_that("prepare_table_ids() refuses missing keys", {
  testthat::expect_error(
    prepare_table_ids(
      data_table = tibble::tibble(
        block = c(1L, NA_integer_),
        name = c("a", "b")
      ),
      vec_sort_columns = c("block", "name"),
      name_id = "row_id",
      name_table = "Tbl"
    ),
    regexp = "missing"
  )
})
