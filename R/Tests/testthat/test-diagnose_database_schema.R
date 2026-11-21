#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_database_schema() passes the fixture", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  vec_md5_before <-
    tools::md5sum(purrr::chuck(list_build, "path_database"))

  res <-
    diagnose_database_schema(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(dplyr::pull(res, check_id), "schema")

  testthat::expect_equal(dplyr::pull(res, scope), "database")

  testthat::expect_equal(dplyr::pull(res, status), "pass")

  # The check only reads the database
  testthat::expect_equal(
    tools::md5sum(purrr::chuck(list_build, "path_database")),
    vec_md5_before
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_database_schema() fails a missing index", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = DBI::dbExecute,
    statement = "DROP INDEX idx_samples_sample_id"
  )

  res <-
    diagnose_database_schema(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(dplyr::pull(res, status), "fail")

  testthat::expect_match(
    dplyr::pull(res, message),
    "idx_samples_sample_id"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_database_schema() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_database_schema(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
