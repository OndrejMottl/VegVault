#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_build_producers() passes a default build", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    diagnose_build_producers(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(dplyr::pull(res, check_id), "build_producers")

  testthat::expect_equal(dplyr::pull(res, scope), "BuildProducers")

  testthat::expect_equal(dplyr::pull(res, status), "pass")

  testthat::expect_equal(dplyr::pull(res, observed), "1")
})

testthat::test_that("diagnose_build_producers() passes a release build", {
  list_build <-
    build_validation_database(
      dir = withr::local_tempdir(),
      profile = "release",
      tag = "v2.0.0",
      commit_sha = base::strrep("a", 40L)
    )

  res <-
    diagnose_build_producers(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(dplyr::pull(res, status), "pass")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_build_producers() needs a commit to release", {
  list_build <-
    build_validation_database(
      dir = withr::local_tempdir(),
      profile = "release",
      tag = "v2.0.0"
    )

  res <-
    diagnose_build_producers(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(dplyr::pull(res, scope), "splot_plots")

  testthat::expect_equal(dplyr::pull(res, status), "fail")

  testthat::expect_match(dplyr::pull(res, message), "commit")
})

testthat::test_that("diagnose_build_producers() fails rows unlike the pins", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  # Another tag for the pinned artefact and a row for one not pinned; the
  #   row of an older version is not checked
  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(.x, "UPDATE BuildProducers SET tag = 'v9.9.9'")
      DBI::dbExecute(
        .x,
        "INSERT INTO BuildProducers VALUES (2, 'bien_plots', NULL, NULL)"
      )
      DBI::dbExecute(
        .x,
        "INSERT INTO BuildProducers VALUES (1, 'wosis_soil', NULL, NULL)"
      )
    }
  )

  res <-
    diagnose_build_producers(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_setequal(
    dplyr::pull(res, scope),
    c("splot_plots", "bien_plots")
  )

  testthat::expect_true(base::all(dplyr::pull(res, status) == "fail"))
})

testthat::test_that("diagnose_build_producers() fails a missing row", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = DBI::dbExecute,
    statement = "DELETE FROM BuildProducers"
  )

  res <-
    diagnose_build_producers(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(dplyr::pull(res, scope), "splot_plots")

  testthat::expect_equal(dplyr::pull(res, status), "fail")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_build_producers() refuses another database", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  testthat::expect_error(
    diagnose_build_producers(
      path_database = purrr::chuck(list_build, "path_database"),
      list_build_manifest = base::list(
        database = base::list(file_name = "Other.sqlite")
      )
    ),
    regexp = "not the database of the build manifest"
  )
})
