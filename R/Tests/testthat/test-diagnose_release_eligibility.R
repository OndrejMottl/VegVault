#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_release_eligibility() passes a release", {
  data_checks <-
    build_check_result(
      check_id = "integrity",
      scope = "integrity_check",
      status = "pass",
      observed = "ok",
      threshold = "ok",
      message = "ok"
    )

  res <-
    diagnose_release_eligibility(
      list_build_manifest = base::list(
        profile = "release",
        subset = base::list(enabled = FALSE),
        git_clean = TRUE
      ),
      data_checks = data_checks
    )

  testthat::expect_named(
    res,
    c("check_id", "scope", "status", "observed", "threshold", "message")
  )

  testthat::expect_equal(dplyr::pull(res, check_id), "release_eligibility")

  testthat::expect_equal(dplyr::pull(res, scope), "build")

  testthat::expect_equal(dplyr::pull(res, status), "pass")

  testthat::expect_equal(dplyr::pull(res, observed), "TRUE")
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("diagnose_release_eligibility() flags each reason", {
  data_checks <-
    dplyr::bind_rows(
      build_check_result(
        check_id = "integrity",
        scope = "quick_check",
        status = "pass",
        message = "ok"
      ),
      build_check_result(
        check_id = "foreign_keys",
        scope = "Samples -> Datasets",
        status = "fail",
        message = "orphans"
      )
    )

  res <-
    diagnose_release_eligibility(
      list_build_manifest = base::list(
        profile = "subset",
        subset = base::list(enabled = TRUE),
        git_clean = FALSE
      ),
      data_checks = data_checks
    )

  testthat::expect_equal(dplyr::pull(res, status), "flag")

  testthat::expect_equal(dplyr::pull(res, observed), "FALSE")

  vec_patterns <-
    c("subset", "enabled", "clean", "1 check failed", "integrity_check")

  purrr::walk(
    .x = vec_patterns,
    .f = ~ testthat::expect_match(dplyr::pull(res, message), .x)
  )
})

testthat::test_that("diagnose_release_eligibility() flags a default build", {
  res <-
    diagnose_release_eligibility(
      list_build_manifest = base::list(
        profile = "default",
        subset = base::list(enabled = FALSE),
        git_clean = TRUE
      ),
      data_checks = build_check_result(
        check_id = "integrity",
        scope = "integrity_check",
        status = "pass",
        message = "ok"
      )
    )

  testthat::expect_equal(dplyr::pull(res, status), "flag")

  testthat::expect_match(dplyr::pull(res, message), "default profile")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("diagnose_release_eligibility() checks its arguments", {
  list_build_manifest <-
    base::list(
      profile = "release",
      subset = base::list(enabled = FALSE),
      git_clean = TRUE
    )

  testthat::expect_error(
    diagnose_release_eligibility(
      list_build_manifest = list_build_manifest,
      data_checks = tibble::tibble(check_id = "integrity")
    ),
    regexp = "data_checks"
  )

  testthat::expect_error(
    diagnose_release_eligibility(
      list_build_manifest = base::list(profile = "release"),
      data_checks = build_check_result(
        check_id = "integrity",
        scope = "integrity_check",
        status = "pass",
        message = "ok"
      )
    ),
    regexp = "list_build_manifest"
  )
})
