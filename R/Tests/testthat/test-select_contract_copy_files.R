#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("select_contract_copy_files() validates its input", {
  dir_root <-
    withr::local_tempdir()

  testthat::expect_error(
    select_contract_copy_files(
      path_vegvault = base::file.path(dir_root, "missing_folder"),
      repository = "OndrejMottl/VegVault-Vegetation_data"
    ),
    regexp = "path_vegvault"
  )

  testthat::expect_error(
    select_contract_copy_files(
      path_vegvault = dir_root,
      repository = c("a", "b")
    ),
    regexp = "repository"
  )

  testthat::expect_error(
    select_contract_copy_files(
      path_vegvault = dir_root,
      repository = ""
    ),
    regexp = "repository"
  )
})


#----------------------------------------------------------#
# Outputs and functionality -----
#----------------------------------------------------------#

testthat::test_that("select_contract_copy_files() lists a producer's files", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  path_vegvault <-
    purrr::chuck(list_paths, "path_vegvault")

  res <-
    select_contract_copy_files(
      path_vegvault = path_vegvault,
      repository = "OndrejMottl/VegVault-Vegetation_data"
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c("path", "sha256", "contract_id", "contract_version")
  )

  vec_paths_expected <-
    c(
      "Data/Contracts/bien_plots.yml",
      "Data/Contracts/splot_plots.yml",
      "R/Functions/Contracts/load_example_contract.R",
      "R/Functions/Contracts/validate_example_artefact.R"
    )

  testthat::expect_equal(dplyr::pull(res, path), vec_paths_expected)

  testthat::expect_equal(
    dplyr::pull(res, contract_id),
    c("bien_plots", "splot_plots", NA_character_, NA_character_)
  )

  vec_versions_expected <-
    purrr::map_chr(
      .x = c("bien_plots", "splot_plots"),
      .f = ~ yaml::read_yaml(
        file = base::file.path(
          path_vegvault, "Data", "Contracts", stringr::str_c(.x, ".yml")
        )
      ) |>
        purrr::chuck("contract_version")
    )

  testthat::expect_equal(
    dplyr::pull(res, contract_version),
    c(vec_versions_expected, NA_character_, NA_character_)
  )

  vec_sha256_expected <-
    purrr::map_chr(
      .x = vec_paths_expected,
      .f = ~ compute_text_file_sha256(
        path_file = base::file.path(path_vegvault, .x)
      )
    )

  testthat::expect_equal(dplyr::pull(res, sha256), vec_sha256_expected)
})

testthat::test_that("select_contract_copy_files() keeps other producers out", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  res <-
    select_contract_copy_files(
      path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
      repository = "OndrejMottl/VegVault-abiotic_data"
    )

  testthat::expect_equal(
    dplyr::pull(res, path),
    c(
      "Data/Contracts/wosis_soil.yml",
      "R/Functions/Contracts/load_example_contract.R",
      "R/Functions/Contracts/validate_example_artefact.R"
    )
  )
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("select_contract_copy_files() needs a producer contract", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  testthat::expect_error(
    select_contract_copy_files(
      path_vegvault = purrr::chuck(list_paths, "path_vegvault"),
      repository = "OndrejMottl/VegVault-FOSSILPOL"
    ),
    regexp = "OndrejMottl/VegVault-FOSSILPOL"
  )
})

testthat::test_that("select_contract_copy_files() needs contract functions", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  path_vegvault <-
    purrr::chuck(list_paths, "path_vegvault")

  base::unlink(
    base::file.path(path_vegvault, "R", "Functions", "Contracts"),
    recursive = TRUE
  )

  testthat::expect_error(
    select_contract_copy_files(
      path_vegvault = path_vegvault,
      repository = "OndrejMottl/VegVault-Vegetation_data"
    ),
    regexp = "R/Functions/Contracts"
  )
})

testthat::test_that("select_contract_copy_files() rejects a broken contract", {
  testthat::skip_if(
    base::Sys.which("git") == "",
    message = "git is not available"
  )

  list_paths <-
    build_contract_copy_fixture(dir_root = withr::local_tempdir())

  path_vegvault <-
    purrr::chuck(list_paths, "path_vegvault")

  base::writeLines(
    text = "contract_id: broken_plots",
    con = base::file.path(
      path_vegvault, "Data", "Contracts", "broken_plots.yml"
    )
  )

  testthat::expect_error(
    select_contract_copy_files(
      path_vegvault = path_vegvault,
      repository = "OndrejMottl/VegVault-Vegetation_data"
    ),
    regexp = "broken_plots.yml"
  )
})
