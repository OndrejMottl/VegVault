#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_validation_id() names the build", {
  res <-
    build_validation_id(
      list_build_manifest = base::list(
        version = base::list(version = "2.0.0"),
        profile = "default",
        git_commit = base::strrep("1a2b3c4d", 5L),
        build_time_utc = "2026-11-21T10:15:00Z"
      )
    )

  testthat::expect_type(res, "character")

  testthat::expect_equal(res, "2.0.0_default_1a2b3c4_20261121T101500Z")
})

testthat::test_that("build_validation_id() works on a saved manifest", {
  list_build <-
    build_validation_database(dir = withr::local_tempdir())

  res <-
    build_validation_id(
      list_build_manifest = purrr::chuck(list_build, "list_build_manifest")
    )

  testthat::expect_equal(res, "2.0.0_default_1a2b3c4_20261121T101500Z")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_validation_id() checks the manifest", {
  list_build_manifest <-
    base::list(
      version = base::list(version = "2.0.0"),
      profile = "default",
      git_commit = base::strrep("1a2b3c4d", 5L),
      build_time_utc = "2026-11-21T10:15:00Z"
    )

  testthat::expect_error(
    build_validation_id(
      list_build_manifest = purrr::list_assign(
        list_build_manifest,
        build_time_utc = rlang::zap()
      )
    ),
    regexp = "build_time_utc"
  )

  testthat::expect_error(
    build_validation_id(
      list_build_manifest = purrr::list_assign(
        list_build_manifest,
        profile = "../dev"
      )
    ),
    regexp = "file name"
  )

  testthat::expect_error(
    build_validation_id(
      list_build_manifest = purrr::list_assign(
        list_build_manifest,
        build_time_utc = "21 November 2026"
      )
    ),
    regexp = "build_time_utc"
  )
})
