#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("save_contract_copy() validates its input", {
  dir_root <-
    withr::local_tempdir()

  dir_other <-
    withr::local_tempdir()

  testthat::expect_error(
    save_contract_copy(
      path_producer = base::file.path(dir_root, "missing_folder"),
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = dir_other,
      verbose = FALSE
    ),
    regexp = "path_producer"
  )

  testthat::expect_error(
    save_contract_copy(
      path_producer = dir_root,
      repository = c("a", "b"),
      ref_base = "main",
      path_vegvault = dir_other,
      verbose = FALSE
    ),
    regexp = "repository"
  )

  testthat::expect_error(
    save_contract_copy(
      path_producer = dir_root,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "",
      path_vegvault = dir_other,
      verbose = FALSE
    ),
    regexp = "ref_base"
  )

  testthat::expect_error(
    save_contract_copy(
      path_producer = dir_root,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = base::file.path(dir_other, "missing_folder"),
      verbose = FALSE
    ),
    regexp = "path_vegvault"
  )

  testthat::expect_error(
    save_contract_copy(
      path_producer = dir_root,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = dir_root,
      verbose = FALSE
    ),
    regexp = "path_producer"
  )

  testthat::expect_error(
    save_contract_copy(
      path_producer = dir_root,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = dir_other,
      verbose = "yes"
    ),
    regexp = "verbose"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("save_contract_copy() copies the files and the record", {
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

  res <-
    save_contract_copy(
      path_producer = path_producer,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = path_vegvault,
      verbose = FALSE
    )

  testthat::expect_named(
    res,
    c("vegvault_commit", "producer_repository", "data_files")
  )

  testthat::expect_equal(
    purrr::chuck(res, "vegvault_commit"),
    load_git_commit(path_project = path_vegvault)
  )

  testthat::expect_equal(
    purrr::chuck(res, "producer_repository"),
    "OndrejMottl/VegVault-Vegetation_data"
  )

  data_expected <-
    select_contract_copy_files(
      path_vegvault = path_vegvault,
      repository = "OndrejMottl/VegVault-Vegetation_data"
    )

  testthat::expect_equal(purrr::chuck(res, "data_files"), data_expected)

  # The record on disk says the same
  testthat::expect_equal(
    load_contract_copy_record(path_producer = path_producer),
    res
  )

  vec_files_producer <-
    base::list.files(path = path_producer, recursive = TRUE) |>
    base::sort()

  testthat::expect_equal(
    vec_files_producer,
    base::sort(
      c(
        dplyr::pull(data_expected, path),
        "Data/Contracts/contract_copy.yml"
      )
    )
  )

  # Byte for byte
  vec_is_identical <-
    purrr::map_lgl(
      .x = dplyr::pull(data_expected, path),
      .f = ~ base::identical(
        base::readBin(
          con = base::file.path(path_vegvault, .x),
          what = "raw",
          n = base::file.size(base::file.path(path_vegvault, .x))
        ),
        base::readBin(
          con = base::file.path(path_producer, .x),
          what = "raw",
          n = base::file.size(base::file.path(path_producer, .x))
        )
      )
    )

  testthat::expect_true(base::all(vec_is_identical))
})

testthat::test_that("save_contract_copy() replaces an earlier copy", {
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

  res_first <-
    save_contract_copy(
      path_producer = path_producer,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = path_vegvault,
      verbose = FALSE
    )

  # VegVault drops one contract and adds one function
  run_git_fixture_command(
    path_repo = path_vegvault,
    vec_args = c("rm", "--quiet", "Data/Contracts/bien_plots.yml")
  )

  base::writeLines(
    text = c("load_new_helper <- function() {", "  return(1)", "}"),
    con = base::file.path(
      path_vegvault, "R", "Functions", "Contracts", "load_new_helper.R"
    )
  )

  run_git_fixture_command(
    path_repo = path_vegvault,
    vec_args = c("add", "--all")
  )

  run_git_fixture_command(
    path_repo = path_vegvault,
    vec_args = c("commit", "--quiet", "-m", "second")
  )

  res_second <-
    save_contract_copy(
      path_producer = path_producer,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = path_vegvault,
      verbose = FALSE
    )

  testthat::expect_false(
    purrr::chuck(res_second, "vegvault_commit") ==
      purrr::chuck(res_first, "vegvault_commit")
  )

  testthat::expect_false(
    base::file.exists(
      base::file.path(path_producer, "Data", "Contracts", "bien_plots.yml")
    )
  )

  testthat::expect_true(
    base::file.exists(
      base::file.path(
        path_producer, "R", "Functions", "Contracts", "load_new_helper.R"
      )
    )
  )

  testthat::expect_equal(
    purrr::chuck(res_second, "data_files"),
    select_contract_copy_files(
      path_vegvault = path_vegvault,
      repository = "OndrejMottl/VegVault-Vegetation_data"
    )
  )
})

testthat::test_that("save_contract_copy() reports the copy when verbose", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  testthat::expect_message(
    save_contract_copy(
      path_producer = purrr::chuck(list_paths, "path_producer"),
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
      verbose = TRUE
    ),
    regexp = "Copied 4 files"
  )

  testthat::expect_no_message(
    save_contract_copy(
      path_producer = purrr::chuck(list_paths, "path_producer"),
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
      verbose = FALSE
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("save_contract_copy() needs committed contract files", {
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

  # A change outside the copied folders does not matter
  base::writeLines(
    text = "notes",
    con = base::file.path(path_vegvault, "notes.md")
  )

  testthat::expect_no_error(
    save_contract_copy(
      path_producer = path_producer,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = path_vegvault,
      verbose = FALSE
    )
  )

  base::writeLines(
    text = "draft <- 1",
    con = base::file.path(
      path_vegvault, "R", "Functions", "Contracts", "draft.R"
    )
  )

  testthat::expect_error(
    save_contract_copy(
      path_producer = path_producer,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = path_vegvault,
      verbose = FALSE
    ),
    regexp = "uncommitted"
  )

  # Nothing was copied
  testthat::expect_false(
    base::file.exists(
      base::file.path(path_producer, "R", "Functions", "Contracts", "draft.R")
    )
  )
})

testthat::test_that("save_contract_copy() needs a commit on the ref", {
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

  run_git_fixture_command(
    path_repo = path_vegvault,
    vec_args = c("checkout", "--quiet", "-b", "feature")
  )

  base::writeLines(
    text = "notes",
    con = base::file.path(path_vegvault, "notes.md")
  )

  run_git_fixture_command(
    path_repo = path_vegvault,
    vec_args = c("add", "--all")
  )

  run_git_fixture_command(
    path_repo = path_vegvault,
    vec_args = c("commit", "--quiet", "-m", "feature")
  )

  testthat::expect_error(
    save_contract_copy(
      path_producer = path_producer,
      repository = "OndrejMottl/VegVault-Vegetation_data",
      ref_base = "main",
      path_vegvault = path_vegvault,
      verbose = FALSE
    ),
    regexp = "main"
  )

  vec_files_producer <-
    base::list.files(path = path_producer, recursive = TRUE)

  testthat::expect_length(vec_files_producer, 0L)
})

testthat::test_that("save_contract_copy() keeps the producer's own files", {
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

  base::dir.create(
    base::file.path(path_producer, "R", "Functions", "Contracts"),
    recursive = TRUE
  )

  base::dir.create(
    base::file.path(path_producer, "Data", "Contracts"),
    recursive = TRUE
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
      save_contract_copy(
        path_producer = path_producer,
        repository = "OndrejMottl/VegVault-Vegetation_data",
        ref_base = "main",
        path_vegvault = path_vegvault,
        verbose = FALSE
      )
    )

  testthat::expect_match(
    base::conditionMessage(res_error),
    "own_helper.R",
    fixed = TRUE
  )

  testthat::expect_match(
    base::conditionMessage(res_error),
    "own.yml",
    fixed = TRUE
  )

  testthat::expect_false(
    base::file.exists(
      base::file.path(path_producer, "Data", "Contracts", "contract_copy.yml")
    )
  )
})

testthat::test_that("save_contract_copy() refuses another producer's copy", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  save_contract_copy(
    path_producer = purrr::chuck(list_paths, "path_producer"),
    repository = "OndrejMottl/VegVault-Vegetation_data",
    ref_base = "main",
    path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
    verbose = FALSE
  )

  testthat::expect_error(
    save_contract_copy(
      path_producer = purrr::chuck(list_paths, "path_producer"),
      repository = "OndrejMottl/VegVault-abiotic_data",
      ref_base = "main",
      path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
      verbose = FALSE
    ),
    regexp = "OndrejMottl/VegVault-Vegetation_data"
  )
})

testthat::test_that("save_contract_copy() gives no dependency-scan warning", {
  # targets reads every function a pipeline loads; a ..1 in a purrr
  #   lambda made it warn '..1 may be used in an incorrect context'
  testthat::expect_no_warning(
    targets::tar_deps_raw(save_contract_copy)
  )
})
