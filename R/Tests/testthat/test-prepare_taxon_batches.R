#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_taxon_batches() validates arguments", {
  testthat::expect_error(
    prepare_taxon_batches(
      vec_taxon_names = 1L,
      n_batches = 4L
    ),
    regexp = "vec_taxon_names"
  )
  testthat::expect_error(
    prepare_taxon_batches(
      vec_taxon_names = c("Betula", NA_character_),
      n_batches = 4L
    ),
    regexp = "vec_taxon_names"
  )
  testthat::expect_error(
    prepare_taxon_batches(
      vec_taxon_names = c("Betula", ""),
      n_batches = 4L
    ),
    regexp = "vec_taxon_names"
  )
  testthat::expect_error(
    prepare_taxon_batches(
      vec_taxon_names = "Betula",
      n_batches = 0L
    ),
    regexp = "n_batches"
  )
  testthat::expect_error(
    prepare_taxon_batches(
      vec_taxon_names = "Betula",
      n_batches = 1.5
    ),
    regexp = "n_batches"
  )
  testthat::expect_error(
    prepare_taxon_batches(
      vec_taxon_names = "Betula",
      n_batches = NA_integer_
    ),
    regexp = "n_batches"
  )
  testthat::expect_error(
    prepare_taxon_batches(
      vec_taxon_names = "Betula",
      n_batches = c(2L, 4L)
    ),
    regexp = "n_batches"
  )
  testthat::expect_error(
    prepare_taxon_batches(
      vec_taxon_names = "Betula",
      n_batches = "4"
    ),
    regexp = "n_batches"
  )
})


#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("prepare_taxon_batches() returns one row per name", {
  res <-
    prepare_taxon_batches(
      vec_taxon_names = c("Quercus robur", "Fagus sylvatica", "Betula"),
      n_batches = 1024L
    )

  testthat::expect_s3_class(res, "tbl_df")
  testthat::expect_named(res, c("taxon_name", "batch_id"))
  testthat::expect_type(dplyr::pull(res, batch_id), "integer")
  testthat::expect_equal(base::nrow(res), 3L)

  # Sorted by batch, then by name
  testthat::expect_equal(
    dplyr::pull(res, taxon_name),
    c("Betula", "Fagus sylvatica", "Quercus robur")
  )
})

testthat::test_that("prepare_taxon_batches() keeps the pinned batches", {
  res <-
    prepare_taxon_batches(
      vec_taxon_names = c("Quercus robur", "Fagus sylvatica", "Betula"),
      n_batches = 1024L
    )

  # Pinned, so that a change of the hash between R versions shows here
  testthat::expect_equal(
    dplyr::pull(res, batch_id),
    c(452L, 741L, 897L)
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("prepare_taxon_batches() keeps a name in its batch", {
  vec_names <-
    stringr::str_c("Taxon ", base::seq_len(200L))

  res_first <-
    prepare_taxon_batches(
      vec_taxon_names = vec_names,
      n_batches = 16L
    )

  res_more <-
    prepare_taxon_batches(
      vec_taxon_names = c(
        base::rev(vec_names),
        stringr::str_c("New taxon ", base::seq_len(50L))
      ),
      n_batches = 16L
    )

  data_compared <-
    dplyr::inner_join(
      res_first,
      res_more,
      by = dplyr::join_by(taxon_name),
      suffix = c("_first", "_more")
    )

  testthat::expect_equal(base::nrow(data_compared), 200L)
  testthat::expect_equal(
    dplyr::pull(data_compared, batch_id_first),
    dplyr::pull(data_compared, batch_id_more)
  )
})

testthat::test_that("prepare_taxon_batches() spreads names over batches", {
  res <-
    prepare_taxon_batches(
      vec_taxon_names = stringr::str_c("Taxon ", base::seq_len(5000L)),
      n_batches = 16L
    )

  testthat::expect_equal(base::nrow(res), 5000L)
  testthat::expect_equal(
    base::sort(base::unique(dplyr::pull(res, batch_id))),
    base::seq_len(16L)
  )
  testthat::expect_true(
    base::all(dplyr::pull(dplyr::count(res, batch_id), n) > 200L)
  )
  testthat::expect_false(base::is.unsorted(dplyr::pull(res, batch_id)))
})

testthat::test_that("prepare_taxon_batches() merges repeated names", {
  res <-
    prepare_taxon_batches(
      vec_taxon_names = c("Betula", "Betula", "Quercus robur"),
      n_batches = 4L
    )

  testthat::expect_equal(base::nrow(res), 2L)
  testthat::expect_equal(
    base::sort(dplyr::pull(res, taxon_name)),
    c("Betula", "Quercus robur")
  )
})

testthat::test_that("prepare_taxon_batches() ignores the text encoding", {
  name_utf8 <-
    stringr::str_c("Cr", base::intToUtf8(233L), "pis")

  name_latin1 <-
    base::iconv(name_utf8, from = "UTF-8", to = "latin1")

  res_utf8 <-
    prepare_taxon_batches(
      vec_taxon_names = name_utf8,
      n_batches = 1024L
    )

  res_latin1 <-
    prepare_taxon_batches(
      vec_taxon_names = name_latin1,
      n_batches = 1024L
    )

  testthat::expect_equal(
    dplyr::pull(res_utf8, batch_id),
    dplyr::pull(res_latin1, batch_id)
  )
})

testthat::test_that("prepare_taxon_batches() uses batch 1 when alone", {
  res <-
    prepare_taxon_batches(
      vec_taxon_names = c("Quercus robur", "Fagus sylvatica"),
      n_batches = 1L
    )

  testthat::expect_equal(dplyr::pull(res, batch_id), c(1L, 1L))
})
