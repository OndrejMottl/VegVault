#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_foreign_keys() passes the fixture", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_foreign_keys(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(dplyr::pull(res, check_id), "foreign_keys")

  testthat::expect_equal(dplyr::pull(res, scope), "database")

  testthat::expect_equal(dplyr::pull(res, status), "pass")

  testthat::expect_equal(dplyr::pull(res, observed), "0")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_foreign_keys() reports each child table", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # Two orphans in one table, one in another; RSQLite does not enforce
  #   foreign keys unless asked, as in the bulk load
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(
        .x,
        "INSERT INTO DatasetSample VALUES (998, 1), (999, 2)"
      )
      DBI::dbExecute(
        .x,
        "UPDATE SamplePosition SET position_id = 999 WHERE sample_id = 1"
      )
    }
  )

  res <-
    diagnose_foreign_keys(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c("DatasetSample -> Datasets", "SamplePosition -> Positions")
  )

  testthat::expect_equal(dplyr::pull(res, status), c("fail", "fail"))

  testthat::expect_equal(dplyr::pull(res, observed), c("2", "1"))

  testthat::expect_equal(dplyr::pull(res, threshold), c("0", "0"))
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_foreign_keys() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_foreign_keys(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
