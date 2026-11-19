#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_taxa_classification_counts() counts levels", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  res <-
    load_taxa_classification_counts(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "f.sqlite"))
    )

  testthat::expect_s3_class(res, "tbl_df")

  # 7 taxa; species 1 and 4, genera 2 and 5, families 3 and 6; taxon 7
  #   has no classification row
  testthat::expect_equal(
    res,
    tibble::tibble(
      taxon_level = c(
        "total taxa", "species", "genus", "family", "not classified"
      ),
      n_taxa = c(7L, 2L, 2L, 2L, 1L)
    )
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_taxa_classification_counts() checks the source", {
  path_database <-
    build_database_fixture(
      path_database = base::file.path(withr::local_tempdir(), "f.sqlite")
    )

  testthat::expect_error(
    load_taxa_classification_counts(
      path_database = path_database,
      list_build_manifest = list(database = list(file_name = "other.sqlite"))
    ),
    regexp = "build manifest"
  )
})
