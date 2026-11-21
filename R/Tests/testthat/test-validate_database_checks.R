#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("validate_database_checks() passes flags", {
  data_checks <-
    dplyr::bind_rows(
      build_check_result(
        check_id = "schema",
        scope = "database",
        status = "pass",
        message = "ok"
      ),
      build_check_result(
        check_id = "release_eligibility",
        scope = "build",
        status = "flag",
        message = "dev build"
      )
    )

  testthat::expect_invisible(
    validate_database_checks(
      data_checks = data_checks,
      vec_paths_report = "report.csv"
    )
  )

  testthat::expect_true(
    validate_database_checks(
      data_checks = data_checks,
      vec_paths_report = "report.csv"
    )
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_database_checks() stops on a failure", {
  data_checks <-
    dplyr::bind_rows(
      build_check_result(
        check_id = "schema",
        scope = "database",
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

  vec_paths_report <-
    base::file.path(
      "D:/Private/Folder",
      c("validation_checks_x.csv", "validation_summary_x.md")
    )

  cnd <-
    testthat::expect_error(
      validate_database_checks(
        data_checks = data_checks,
        vec_paths_report = vec_paths_report
      )
    )

  vec_message <-
    base::conditionMessage(cnd)

  testthat::expect_match(vec_message, "foreign_keys")

  testthat::expect_match(vec_message, "Samples -> Datasets", fixed = TRUE)

  testthat::expect_match(vec_message, "validation_summary_x.md")

  testthat::expect_no_match(vec_message, "Private")
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_database_checks() checks the results", {
  testthat::expect_error(
    validate_database_checks(
      data_checks = tibble::tibble(check_id = "schema"),
      vec_paths_report = "report.csv"
    ),
    regexp = "data_checks"
  )
})
