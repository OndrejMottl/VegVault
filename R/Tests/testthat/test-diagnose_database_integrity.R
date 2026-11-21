#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_database_integrity() passes the fixture", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_database_integrity(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(dplyr::pull(res, check_id), "integrity")

  testthat::expect_equal(dplyr::pull(res, scope), "integrity_check")

  testthat::expect_equal(dplyr::pull(res, status), "pass")

  testthat::expect_equal(dplyr::pull(res, observed), "ok")

  # The runtime is reported
  testthat::expect_match(dplyr::pull(res, message), "[0-9.]+ s")
})

testthat::test_that("diagnose_database_integrity() can run quick_check", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_database_integrity(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      flag_quick_check = TRUE
    )

  testthat::expect_equal(dplyr::pull(res, scope), "quick_check")

  testthat::expect_equal(dplyr::pull(res, status), "pass")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_database_integrity() fails a broken row", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  # A NOT NULL constraint added after a missing value was written
  run_with_database(
    path_database = path_database,
    fn = ~ {
      DBI::dbExecute(.x, "CREATE TABLE t (a INTEGER)")
      DBI::dbExecute(.x, "INSERT INTO t VALUES (NULL)")
      DBI::dbExecute(.x, "PRAGMA writable_schema = ON")
      DBI::dbExecute(
        .x,
        base::paste(
          "UPDATE sqlite_schema SET sql =",
          "'CREATE TABLE t (a INTEGER NOT NULL)' WHERE name = 't'"
        )
      )
    }
  )

  list_build_manifest <-
    base::list(database = base::list(file_name = "VegVault.sqlite"))

  purrr::walk(
    .x = c(FALSE, TRUE),
    .f = ~ {
      res <-
        diagnose_database_integrity(
          path_database = path_database,
          list_build_manifest = list_build_manifest,
          flag_quick_check = .x
        )

      testthat::expect_equal(dplyr::pull(res, status), "fail")

      testthat::expect_equal(dplyr::pull(res, observed), "1")

      testthat::expect_match(dplyr::pull(res, message), "NULL value in t.a")
    }
  )
})

testthat::test_that("diagnose_database_integrity() fails an unreadable file", {
  path_database <-
    base::file.path(withr::local_tempdir(), "VegVault.sqlite")

  base::writeBin(
    object = base::as.raw(base::rep(7L, 4096L)),
    con = path_database
  )

  res <-
    diagnose_database_integrity(
      path_database = path_database,
      list_build_manifest = base::list(
        database = base::list(file_name = "VegVault.sqlite")
      )
    )

  testthat::expect_equal(dplyr::pull(res, status), "fail")

  testthat::expect_match(dplyr::pull(res, message), "not a database")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_database_integrity() checks its arguments", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_database_integrity(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      flag_quick_check = "yes"
    ),
    regexp = "flag_quick_check"
  )

  testthat::expect_error(
    diagnose_database_integrity(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
