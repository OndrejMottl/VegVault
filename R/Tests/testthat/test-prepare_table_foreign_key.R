#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_table_foreign_key() validates arguments", {
  data_parent <-
    tibble::tibble(size_id = c(1L, 2L), sample_size = c(10, 20))

  data_child <-
    tibble::tibble(sample_name = "s1", sample_size = 10)

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = "not a table",
      data_parent = data_parent,
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = "Samples"
    ),
    regexp = "data_child"
  )

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = dplyr::select(data_parent, -size_id),
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = "Samples"
    ),
    regexp = "data_parent"
  )

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = dplyr::select(data_child, -sample_size),
      data_parent = data_parent,
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = "Samples"
    ),
    regexp = "vec_key_columns"
  )

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = dplyr::mutate(data_child, size_id = 1L),
      data_parent = data_parent,
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = "Samples"
    ),
    regexp = "name_id"
  )

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = data_parent,
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = c("Samples", "Other")
    ),
    regexp = "name_table"
  )

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = data_parent,
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = "Samples",
      flag_allow_missing = NA
    ),
    regexp = "flag_allow_missing"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_table_foreign_key() adds the parent id", {
  data_parent <-
    tibble::tibble(
      size_id = c(1L, 2L),
      sample_size = c(10, 20),
      description = c("m2", "m2")
    )

  data_child <-
    tibble::tibble(
      sample_name = c("s3", "s1", "s2"),
      sample_size = c(20, 10, 20),
      description = "m2"
    )

  res <-
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = data_parent,
      vec_key_columns = c("sample_size", "description"),
      name_id = "size_id",
      name_table = "Samples"
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(
    res,
    c("sample_name", "sample_size", "description", "size_id")
  )
  testthat::expect_type(dplyr::pull(res, size_id), "integer")
  testthat::expect_equal(dplyr::pull(res, size_id), c(2L, 1L, 2L))
  testthat::expect_equal(
    dplyr::pull(res, sample_name),
    c("s3", "s1", "s2")
  )
})

testthat::test_that("prepare_table_foreign_key() keeps every child row", {
  base::set.seed(900723)

  data_parent <-
    tibble::tibble(
      taxon_id = base::seq_len(50L),
      taxon_name = stringr::str_c("taxon_", base::seq_len(50L))
    )

  data_child <-
    tibble::tibble(
      taxon_name = base::sample(
        x = dplyr::pull(data_parent, taxon_name),
        size = 5000L,
        replace = TRUE
      )
    )

  res <-
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = data_parent,
      vec_key_columns = "taxon_name",
      name_id = "taxon_id",
      name_table = "SampleTaxa"
    )

  testthat::expect_equal(base::nrow(res), 5000L)
  testthat::expect_equal(
    dplyr::pull(res, taxon_name),
    dplyr::pull(data_child, taxon_name)
  )
  testthat::expect_equal(
    dplyr::pull(res, taxon_id),
    base::match(
      dplyr::pull(data_child, taxon_name),
      dplyr::pull(data_parent, taxon_name)
    )
  )
})

testthat::test_that("prepare_table_foreign_key() handles missing keys", {
  data_parent <-
    tibble::tibble(
      size_id = 1L,
      sample_size = 10,
      description = "m2"
    )

  data_child <-
    tibble::tibble(
      sample_name = c("s1", "s2"),
      sample_size = c(10, NA_real_),
      description = c("m2", NA_character_)
    )

  res <-
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = data_parent,
      vec_key_columns = c("sample_size", "description"),
      name_id = "size_id",
      name_table = "Samples",
      flag_allow_missing = TRUE
    )

  testthat::expect_equal(dplyr::pull(res, size_id), c(1L, NA_integer_))

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = data_parent,
      vec_key_columns = c("sample_size", "description"),
      name_id = "size_id",
      name_table = "Samples"
    ),
    regexp = "missing"
  )
})


#----------------------------------------------------------#
# Edge cases and errors -----
#----------------------------------------------------------#

testthat::test_that("prepare_table_foreign_key() refuses unmatched keys", {
  data_parent <-
    tibble::tibble(size_id = 1L, sample_size = 10)

  data_child <-
    tibble::tibble(sample_size = c(10, 30))

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = data_parent,
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = "Samples"
    ),
    regexp = "Samples"
  )

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = data_parent,
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = "Samples",
      flag_allow_missing = TRUE
    ),
    regexp = "30"
  )
})

testthat::test_that("prepare_table_foreign_key() refuses partly missing keys", {
  data_parent <-
    tibble::tibble(size_id = 1L, sample_size = 10, description = "m2")

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = tibble::tibble(
        sample_size = 10,
        description = NA_character_
      ),
      data_parent = data_parent,
      vec_key_columns = c("sample_size", "description"),
      name_id = "size_id",
      name_table = "Samples",
      flag_allow_missing = TRUE
    ),
    regexp = "partly"
  )
})

testthat::test_that("prepare_table_foreign_key() refuses a bad parent", {
  data_child <-
    tibble::tibble(sample_size = 10)

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = tibble::tibble(
        size_id = c(1L, 2L),
        sample_size = c(10, 10)
      ),
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = "Samples"
    ),
    regexp = "repeat"
  )

  testthat::expect_error(
    prepare_table_foreign_key(
      data_child = data_child,
      data_parent = tibble::tibble(
        size_id = NA_integer_,
        sample_size = 10
      ),
      vec_key_columns = "sample_size",
      name_id = "size_id",
      name_table = "Samples"
    ),
    regexp = "size_id"
  )
})
