#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_sample_taxa_pairs() passes the fixture", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_sample_taxa_pairs(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(dplyr::pull(res, check_id), "sample_taxa_pairs")

  testthat::expect_equal(dplyr::pull(res, scope), "SampleTaxa")

  testthat::expect_equal(dplyr::pull(res, status), "pass")

  testthat::expect_equal(dplyr::pull(res, observed), "0")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_sample_taxa_pairs() flags pairs per source", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # Sample 1 (sPlotOpen) repeats taxon 1 twice more, sample 6 (BIEN) once
  #   more; sample 99 belongs to no dataset
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = DBI::dbExecute,
    statement = base::paste(
      "INSERT INTO SampleTaxa VALUES (1, 1, 7), (1, 1, 8), (6, 1, 2),",
      "(99, 1, 1), (99, 1, 1)"
    )
  )

  res <-
    diagnose_sample_taxa_pairs(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c("(no source)", "BIEN", "sPlotOpen")
  )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "flag"))

  testthat::expect_equal(dplyr::pull(res, observed), c("1", "1", "1"))

  testthat::expect_match(dplyr::pull(res, message)[3], "3 rows")

  testthat::expect_match(dplyr::pull(res, message)[2], "2 rows")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_sample_taxa_pairs() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_sample_taxa_pairs(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
