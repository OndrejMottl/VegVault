#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_target_store_contract() validates arguments", {
  testthat::expect_error(
    validate_target_store_contract(
      store = 1,
      target_names = "data_alpha",
      runner = "R/run.R"
    ),
    regexp = "arguments are invalid"
  )

  testthat::expect_error(
    validate_target_store_contract(
      store = "store",
      target_names = base::character(0),
      runner = "R/run.R"
    ),
    regexp = "arguments are invalid"
  )

  testthat::expect_error(
    validate_target_store_contract(
      store = "store",
      target_names = "data_alpha",
      runner = ""
    ),
    regexp = "arguments are invalid"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_target_store_contract() returns metadata", {
  dir_root <-
    withr::local_tempdir()

  path_store <-
    build_example_target_store(dir_root = dir_root)

  res <-
    validate_target_store_contract(
      store = path_store,
      target_names = "data_alpha",
      runner = "R/run.R"
    )

  testthat::expect_s3_class(res, "data.frame")

  testthat::expect_named(res, c("name", "data"))

  testthat::expect_equal(
    dplyr::pull(res, name),
    "data_alpha"
  )
})


#----------------------------------------------------------#
# Edge cases and messages -----
#----------------------------------------------------------#

testthat::test_that("validate_target_store_contract() names the runner", {
  dir_root <-
    withr::local_tempdir()

  testthat::expect_error(
    validate_target_store_contract(
      store = base::file.path(dir_root, "missing_store"),
      target_names = "data_alpha",
      runner = "R/Analyses/01_Stage/00_run.R"
    ),
    regexp = "does not exist"
  )

  testthat::expect_error(
    validate_target_store_contract(
      store = base::file.path(dir_root, "missing_store"),
      target_names = "data_alpha",
      runner = "R/Analyses/01_Stage/00_run.R"
    ),
    regexp = "01_Stage/00_run.R",
    fixed = TRUE
  )
})

testthat::test_that("validate_target_store_contract() flags missing targets", {
  dir_root <-
    withr::local_tempdir()

  path_store <-
    build_example_target_store(dir_root = dir_root)

  testthat::expect_error(
    validate_target_store_contract(
      store = path_store,
      target_names = c("data_alpha", "data_gamma"),
      runner = "R/run.R"
    ),
    regexp = "missing public targets"
  )

  testthat::expect_error(
    validate_target_store_contract(
      store = path_store,
      target_names = c("data_alpha", "data_gamma"),
      runner = "R/Analyses/01_Stage/00_run.R"
    ),
    regexp = "01_Stage/00_run.R",
    fixed = TRUE
  )
})

testthat::test_that("validate_target_store_contract() flags a failed run", {
  dir_root <-
    withr::local_tempdir()

  build_example_target_store(dir_root = dir_root)

  # The rebuild of data_alpha fails; its last good value stays in the store
  base::try(
    build_example_target_store(
      dir_root = dir_root,
      command_alpha = "stop('broken')"
    ),
    silent = TRUE
  )

  path_store <-
    base::file.path(dir_root, "store")

  testthat::expect_error(
    validate_target_store_contract(
      store = path_store,
      target_names = "data_alpha",
      runner = "R/Analyses/01_Stage/00_run.R"
    ),
    regexp = "did\\s+not\\s+finish"
  )

  # Also for a public target that did not fail itself
  res_error <-
    testthat::expect_error(
      validate_target_store_contract(
        store = path_store,
        target_names = "data_beta",
        runner = "R/Analyses/01_Stage/00_run.R"
      ),
      regexp = "data_alpha"
    )

  testthat::expect_match(
    base::conditionMessage(res_error),
    "01_Stage/00_run.R",
    fixed = TRUE
  )
})

testthat::test_that("validate_target_store_contract() flags a canceled run", {
  dir_root <-
    withr::local_tempdir()

  path_store <-
    build_example_target_store(
      dir_root = dir_root,
      command_alpha = "targets::tar_cancel()"
    )

  testthat::expect_error(
    validate_target_store_contract(
      store = path_store,
      target_names = "data_beta",
      runner = "R/run.R"
    ),
    regexp = "did\\s+not\\s+finish"
  )
})

testthat::test_that("validate_target_store_contract() needs a full run", {
  dir_root <-
    withr::local_tempdir()

  path_store <-
    build_example_target_store(dir_root = dir_root)

  # A run of one selected target leaves data_alpha out of the latest run
  targets::tar_make(
    script = base::file.path(dir_root, "pipeline.R"),
    store = path_store,
    names = "data_beta",
    callr_function = NULL,
    reporter = "silent"
  )

  testthat::expect_error(
    validate_target_store_contract(
      store = path_store,
      target_names = "data_alpha",
      runner = "R/Analyses/01_Stage/00_run.R"
    ),
    regexp = "not\\s+built\\s+or\\s+checked"
  )

  testthat::expect_no_error(
    validate_target_store_contract(
      store = path_store,
      target_names = "data_beta",
      runner = "R/Analyses/01_Stage/00_run.R"
    )
  )
})
