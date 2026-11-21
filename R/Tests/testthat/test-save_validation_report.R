#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("save_validation_report() writes the table and summary", {
  dir_output <-
    base::file.path(withr::local_tempdir(), "Tables")

  list_build_manifest <-
    base::list(
      version = base::list(version = "2.0.0"),
      profile = "default",
      git_commit = base::strrep("1a2b3c4d", 5L),
      build_time_utc = "2026-11-21T10:15:00Z"
    )

  data_checks <-
    dplyr::bind_rows(
      build_check_result(
        check_id = "schema",
        scope = "database",
        status = "pass",
        message = "The database matches the schema file."
      ),
      build_check_result(
        check_id = "foreign_keys",
        scope = "Samples -> Datasets",
        status = "fail",
        observed = 2L,
        threshold = 0L,
        message = "2 rows of Samples have no parent row in Datasets."
      ),
      build_check_result(
        check_id = "release_eligibility",
        scope = "build",
        status = "flag",
        observed = FALSE,
        threshold = TRUE,
        message = "Not eligible: the build used the dev profile."
      )
    )

  res <-
    save_validation_report(
      data_checks = data_checks,
      list_build_manifest = list_build_manifest,
      dir_output = dir_output
    )

  testthat::expect_equal(
    base::basename(res),
    c(
      "validation_checks_2.0.0_default_1a2b3c4_20261121T101500Z.csv",
      "validation_summary_2.0.0_default_1a2b3c4_20261121T101500Z.md"
    )
  )

  testthat::expect_true(base::all(base::file.exists(res)))

  data_read <-
    readr::read_csv(
      file = res[1],
      col_types = readr::cols(.default = readr::col_character()),
      na = ""
    )

  # readr adds its own class and the column specification
  testthat::expect_equal(
    tibble::as_tibble(data_read),
    data_checks,
    ignore_attr = TRUE
  )

  vec_summary <-
    base::readLines(res[2])

  testthat::expect_true(
    base::any(stringr::str_detect(vec_summary, "Release eligible: no"))
  )

  testthat::expect_true(
    base::any(stringr::str_detect(vec_summary, "1 pass, 1 fail, 1 flag"))
  )

  testthat::expect_true(
    base::any(
      stringr::str_detect(
        vec_summary,
        stringr::fixed("`foreign_keys` (Samples -> Datasets)")
      )
    )
  )
})

testthat::test_that("save_validation_report() replaces a report of the build", {
  dir_output <-
    withr::local_tempdir()

  list_build_manifest <-
    base::list(
      version = base::list(version = "2.0.0"),
      profile = "release",
      git_commit = base::strrep("1a2b3c4d", 5L),
      build_time_utc = "2026-11-21T10:15:00Z"
    )

  data_checks <-
    build_check_result(
      check_id = "release_eligibility",
      scope = "build",
      status = "pass",
      observed = TRUE,
      threshold = TRUE,
      message = "Eligible for release."
    )

  save_validation_report(
    data_checks = build_check_result(
      check_id = "schema",
      scope = "database",
      status = "fail",
      message = "x"
    ),
    list_build_manifest = list_build_manifest,
    dir_output = dir_output
  )

  res <-
    save_validation_report(
      data_checks = data_checks,
      list_build_manifest = list_build_manifest,
      dir_output = dir_output
    )

  testthat::expect_length(base::list.files(dir_output), 2L)

  testthat::expect_true(
    base::any(stringr::str_detect(base::readLines(res[2]), "eligible: yes"))
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_validation_report() checks the results", {
  testthat::expect_error(
    save_validation_report(
      data_checks = tibble::tibble(check_id = "schema", status = "pass"),
      list_build_manifest = base::list(
        version = base::list(version = "2.0.0"),
        profile = "default",
        git_commit = base::strrep("1a2b3c4d", 5L),
        build_time_utc = "2026-11-21T10:15:00Z"
      ),
      dir_output = withr::local_tempdir()
    ),
    regexp = "data_checks"
  )
})
