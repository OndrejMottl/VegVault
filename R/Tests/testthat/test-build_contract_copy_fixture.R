#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_contract_copy_fixture() validates its input", {
  dir_root <-
    withr::local_tempdir()

  testthat::expect_error(
    build_contract_copy_fixture(
      dir_root = base::file.path(dir_root, "missing_folder")
    ),
    regexp = "dir_root"
  )

  base::writeLines(text = "x", con = base::file.path(dir_root, "a.txt"))

  testthat::expect_error(
    build_contract_copy_fixture(dir_root = dir_root),
    regexp = "dir_root"
  )

  dir_empty <-
    withr::local_tempdir()

  testthat::expect_error(
    build_contract_copy_fixture(
      dir_root = dir_empty,
      path_contracts = dir_root
    ),
    regexp = "splot_plots.yml"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("build_contract_copy_fixture() builds both folders", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_root <-
    withr::local_tempdir()

  res <-
    build_contract_copy_fixture(dir_root = dir_root)

  testthat::expect_type(res, "list")

  testthat::expect_named(res, c("path_vegvault", "path_producer"))

  testthat::expect_true(base::dir.exists(purrr::chuck(res, "path_vegvault")))

  testthat::expect_true(base::dir.exists(purrr::chuck(res, "path_producer")))

  vec_producer_files <-
    base::list.files(
      path = purrr::chuck(res, "path_producer"),
      all.files = TRUE,
      no.. = TRUE
    )

  testthat::expect_length(vec_producer_files, 0L)

  vec_files <-
    base::list.files(
      path = purrr::chuck(res, "path_vegvault"),
      recursive = TRUE
    ) |>
    base::sort()

  testthat::expect_equal(
    vec_files,
    base::sort(
      c(
        "Data/Contracts/README.md",
        "Data/Contracts/bien_plots.yml",
        "Data/Contracts/fixtures/valid/splot_plots/example.txt",
        "Data/Contracts/old_plots.yml",
        "Data/Contracts/splot_plots.yml",
        "Data/Contracts/hwsd_soil.yml",
        "R/Functions/Contracts/load_example_contract.R",
        "R/Functions/Contracts/validate_example_artefact.R"
      )
    )
  )
})

testthat::test_that("build_contract_copy_fixture() commits on main", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_root <-
    withr::local_tempdir()

  res <-
    build_contract_copy_fixture(dir_root = dir_root)

  path_vegvault <-
    purrr::chuck(res, "path_vegvault")

  testthat::expect_true(is_git_clean(path_project = path_vegvault))

  res_branch <-
    run_git_fixture_command(
      path_repo = path_vegvault,
      vec_args = c("rev-parse", "--abbrev-ref", "HEAD")
    )

  testthat::expect_equal(res_branch, "main")

  res_commits <-
    run_git_fixture_command(
      path_repo = path_vegvault,
      vec_args = c("rev-list", "--count", "HEAD")
    )

  testthat::expect_equal(res_commits, "1")
})

testthat::test_that("build_contract_copy_fixture() writes valid contracts", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_root <-
    withr::local_tempdir()

  res <-
    build_contract_copy_fixture(dir_root = dir_root)

  path_contracts <-
    base::file.path(purrr::chuck(res, "path_vegvault"), "Data", "Contracts")

  list_contracts <-
    purrr::map(
      .x = c("splot_plots", "bien_plots", "hwsd_soil", "old_plots"),
      .f = ~ load_producer_contract(
        path_contract = base::file.path(
          path_contracts,
          stringr::str_c(.x, ".yml")
        )
      )
    )

  vec_repositories <-
    purrr::map_chr(
      .x = list_contracts,
      .f = ~ purrr::chuck(.x, "producer", "repository")
    )

  testthat::expect_equal(
    vec_repositories,
    c(
      "OndrejMottl/VegVault-Vegetation_data",
      "OndrejMottl/VegVault-Vegetation_data",
      "OndrejMottl/VegVault-abiotic_data",
      "OndrejMottl/VegVault-Vegetation_data"
    )
  )

  vec_status <-
    purrr::map_chr(
      .x = list_contracts,
      .f = ~ purrr::chuck(.x, "status")
    )

  testthat::expect_equal(
    vec_status,
    c("active", "active", "active", "retired")
  )

  # The real contracts keep their text
  testthat::expect_equal(
    compute_text_file_sha256(
      path_file = base::file.path(path_contracts, "splot_plots.yml")
    ),
    compute_text_file_sha256(
      path_file = here::here("Data", "Contracts", "splot_plots.yml")
    )
  )
})

testthat::test_that("build_contract_copy_fixture() writes LF line endings", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  dir_root <-
    withr::local_tempdir()

  res <-
    build_contract_copy_fixture(dir_root = dir_root)

  vec_paths <-
    base::list.files(
      path = purrr::chuck(res, "path_vegvault"),
      recursive = TRUE,
      full.names = TRUE
    )

  vec_has_cr <-
    purrr::map_lgl(
      .x = vec_paths,
      .f = ~ base::any(
        base::readBin(
          con = .x,
          what = "raw",
          n = base::file.size(.x)
        ) == base::as.raw(13L)
      )
    )

  testthat::expect_false(base::any(vec_has_cr))

  # The function files define the functions they are named after
  env_functions <-
    base::new.env()

  base::sys.source(
    file = base::file.path(
      purrr::chuck(res, "path_vegvault"),
      "R", "Functions", "Contracts", "load_example_contract.R"
    ),
    envir = env_functions
  )

  testthat::expect_true(
    base::exists(
      x = "load_example_contract",
      envir = env_functions,
      inherits = FALSE
    )
  )
})
