#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_version_row() passes the fixture", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_version_row(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      list_version = purrr::chuck(list_build, "list_version"),
      path_producer_manifest = purrr::chuck(
        list_build, "path_producer_manifest"
      )
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(
    dplyr::pull(res, scope),
    c("version", "changelog", "build_profile", "git_commit", "manifest_sha256")
  )

  testthat::expect_true(base::all(dplyr::pull(res, check_id) == "version_row"))

  testthat::expect_true(base::all(dplyr::pull(res, status) == "pass"))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_version_row() reads the row with the top id", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # Written last, but with the lowest id
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = DBI::dbExecute,
    statement = base::paste(
      "INSERT INTO version_control (id, version, changelog)",
      "VALUES (0, '0.0.1', 'Test row')"
    )
  )

  res <-
    diagnose_version_row(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      list_version = purrr::chuck(list_build, "list_version"),
      path_producer_manifest = purrr::chuck(
        list_build, "path_producer_manifest"
      )
    )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "pass"))
})

testthat::test_that("diagnose_version_row() fails each field", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = DBI::dbExecute,
    statement = base::paste(
      "UPDATE version_control SET changelog = ' ', build_profile = 'subset',",
      "git_commit = 'abc' WHERE id = 2"
    )
  )

  # The pin manifest changed after the build
  base::write(
    x = "# edited",
    file = purrr::chuck(list_build, "path_producer_manifest"),
    append = TRUE
  )

  res <-
    diagnose_version_row(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      list_version = base::list(version = "2.0.1"),
      path_producer_manifest = purrr::chuck(
        list_build, "path_producer_manifest"
      )
    )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "fail"))

  data_version <-
    dplyr::filter(res, scope == "version")

  testthat::expect_equal(dplyr::pull(data_version, observed), "2.0.0")

  testthat::expect_equal(dplyr::pull(data_version, threshold), "2.0.1")
})

testthat::test_that("diagnose_version_row() fails a missing row", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(.x, "DELETE FROM BuildProducers")
      DBI::dbExecute(.x, "DELETE FROM version_control")
    }
  )

  res <-
    diagnose_version_row(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      list_version = purrr::chuck(list_build, "list_version"),
      path_producer_manifest = purrr::chuck(
        list_build, "path_producer_manifest"
      )
    )

  testthat::expect_equal(dplyr::pull(res, scope), "version_control")

  testthat::expect_equal(dplyr::pull(res, status), "fail")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_version_row() checks its arguments", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_version_row(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      list_version = base::list(changelog = "x"),
      path_producer_manifest = purrr::chuck(
        list_build, "path_producer_manifest"
      )
    ),
    regexp = "list_version"
  )

  testthat::expect_error(
    diagnose_version_row(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest"),
      list_version = purrr::chuck(list_build, "list_version"),
      path_producer_manifest = base::file.path(
        withr::local_tempdir(), "missing.yml"
      )
    ),
    regexp = "path_producer_manifest"
  )
})
