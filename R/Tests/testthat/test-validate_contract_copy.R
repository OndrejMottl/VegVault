#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("validate_contract_copy() validates its input", {
  dir_producer <-
    withr::local_tempdir()

  testthat::expect_error(
    validate_contract_copy(
      path_producer = base::file.path(dir_producer, "missing_folder")
    ),
    regexp = "path_producer"
  )

  testthat::expect_error(
    validate_contract_copy(
      path_producer = dir_producer,
      path_vegvault = c("a", "b")
    ),
    regexp = "path_vegvault"
  )

  testthat::expect_error(
    validate_contract_copy(
      path_producer = dir_producer,
      verbose = NA
    ),
    regexp = "verbose"
  )

  # A producer without a copy has no record
  testthat::expect_error(
    validate_contract_copy(
      path_producer = dir_producer,
      verbose = FALSE
    ),
    regexp = "contract_copy.yml"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("validate_contract_copy() passes a fresh copy", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  path_vegvault <-
    purrr::chuck(list_paths, "path_vegvault")

  path_producer <-
    purrr::chuck(list_paths, "path_producer")

  list_record <-
    save_contract_copy(
      path_producer = path_producer,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = path_vegvault,
      verbose = FALSE
    )

  testthat::expect_invisible(
    validate_contract_copy(
      path_producer = path_producer,
      verbose = FALSE
    )
  )

  res <-
    validate_contract_copy(
      path_producer = path_producer,
      path_vegvault = path_vegvault,
      verbose = FALSE
    )

  testthat::expect_equal(res, purrr::chuck(list_record, "data_files"))
})

testthat::test_that("validate_contract_copy() ignores line endings", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  path_producer <-
    purrr::chuck(list_paths, "path_producer")

  save_contract_copy(
    path_producer = path_producer,
    repository = "OndrejMottl/VegVault-Vegetation_data",
    ref_base = "main",
    path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
    verbose = FALSE
  )

  path_contract <-
    base::file.path(path_producer, "Data", "Contracts", "splot_plots.yml")

  vec_bytes_lf <-
    base::readBin(
      con = path_contract,
      what = "raw",
      n = base::file.size(path_contract)
    )

  # A checkout with CRLF line endings, as git gives on Windows
  text_crlf <-
    base::rawToChar(vec_bytes_lf) |>
    stringr::str_replace_all(pattern = "\n", replacement = "\r\n")

  base::writeBin(
    object = base::charToRaw(text_crlf),
    con = path_contract
  )

  testthat::expect_no_error(
    validate_contract_copy(
      path_producer = path_producer,
      path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
      verbose = FALSE
    )
  )
})

testthat::test_that("validate_contract_copy() reports its result", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  path_producer <-
    purrr::chuck(list_paths, "path_producer")

  save_contract_copy(
    path_producer = path_producer,
    repository = "OndrejMottl/VegVault-Vegetation_data",
    ref_base = "main",
    path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
    verbose = FALSE
  )

  testthat::expect_message(
    validate_contract_copy(
      path_producer = path_producer,
      path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
      verbose = TRUE
    ),
    regexp = "matches"
  )

  # Without the VegVault checkout the comparison is skipped
  testthat::expect_message(
    validate_contract_copy(
      path_producer = path_producer,
      path_vegvault = base::file.path(path_producer, "missing_folder"),
      verbose = TRUE
    ),
    regexp = "skipped"
  )

  testthat::expect_no_message(
    validate_contract_copy(
      path_producer = path_producer,
      path_vegvault = base::file.path(path_producer, "missing_folder"),
      verbose = FALSE
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("validate_contract_copy() detects a changed copy", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  path_producer <-
    purrr::chuck(list_paths, "path_producer")

  save_contract_copy(
    path_producer = path_producer,
    repository = "OndrejMottl/VegVault-Vegetation_data",
    ref_base = "main",
    path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
    verbose = FALSE
  )

  # An edited contract, a deleted function and two files of the producer
  base::write(
    x = "# edited",
    file = base::file.path(
      path_producer, "Data", "Contracts", "splot_plots.yml"
    ),
    append = TRUE
  )

  base::file.remove(
    base::file.path(
      path_producer, "R", "Functions", "Contracts",
      "validate_example_artefact.R"
    )
  )

  base::writeLines(
    text = "own_helper <- 1",
    con = base::file.path(
      path_producer, "R", "Functions", "Contracts", "own_helper.R"
    )
  )

  base::writeLines(
    text = "id: own",
    con = base::file.path(path_producer, "Data", "Contracts", "own.yml")
  )

  res_error <-
    testthat::expect_error(
      validate_contract_copy(
        path_producer = path_producer,
        verbose = FALSE
      ),
      class = "contract_copy_error"
    )

  text_message <-
    base::conditionMessage(res_error)

  testthat::expect_match(text_message, "splot_plots.yml", fixed = TRUE)

  testthat::expect_match(
    text_message,
    "validate_example_artefact.R",
    fixed = TRUE
  )

  testthat::expect_match(text_message, "own_helper.R", fixed = TRUE)

  testthat::expect_match(text_message, "own.yml", fixed = TRUE)

  testthat::expect_match(text_message, "save_contract_copy")
})

testthat::test_that("validate_contract_copy() detects an outdated copy", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  path_vegvault <-
    purrr::chuck(list_paths, "path_vegvault")

  path_producer <-
    purrr::chuck(list_paths, "path_producer")

  save_contract_copy(
    path_producer = path_producer,
    repository = "OndrejMottl/VegVault-Vegetation_data",
    ref_base = "main",
    path_vegvault = path_vegvault,
    verbose = FALSE
  )

  # VegVault changes one contract, drops another and adds a function
  base::write(
    x = "# a later note",
    file = base::file.path(
      path_vegvault, "Data", "Contracts", "splot_plots.yml"
    ),
    append = TRUE
  )

  base::file.remove(
    base::file.path(path_vegvault, "Data", "Contracts", "bien_plots.yml")
  )

  base::writeLines(
    text = c("load_new_helper <- function() {", "  return(1)", "}"),
    con = base::file.path(
      path_vegvault, "R", "Functions", "Contracts", "load_new_helper.R"
    )
  )

  # The copy itself is unchanged
  testthat::expect_no_error(
    validate_contract_copy(
      path_producer = path_producer,
      verbose = FALSE
    )
  )

  res_error <-
    testthat::expect_error(
      validate_contract_copy(
        path_producer = path_producer,
        path_vegvault = path_vegvault,
        verbose = FALSE
      ),
      class = "contract_copy_error"
    )

  text_message <-
    base::conditionMessage(res_error)

  testthat::expect_match(text_message, "splot_plots.yml", fixed = TRUE)

  testthat::expect_match(text_message, "bien_plots.yml", fixed = TRUE)

  testthat::expect_match(text_message, "load_new_helper.R", fixed = TRUE)

  testthat::expect_false(
    stringr::str_detect(text_message, "load_example_contract.R")
  )
})
