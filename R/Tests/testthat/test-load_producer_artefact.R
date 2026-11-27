#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_artefact() reads every partition", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  data_manifest <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    )

  data_files <-
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "bien_traits",
      mode = "dev",
      dir_dev_root = purrr::chuck(list_fixture, "dir_dev_root"),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    )

  res <-
    load_producer_artefact(data_files = data_files)

  testthat::expect_type(res, "list")

  testthat::expect_named(res, dplyr::pull(data_files, file_name))

  testthat::expect_true(base::all(purrr::map_lgl(res, base::is.data.frame)))

  # The form the contract validator takes
  testthat::expect_no_error(
    validate_producer_artefact(
      contract = here::here("Data", "Contracts", "bien_traits.yml"),
      data_artefact = res,
      verbose = FALSE
    )
  )
})

testthat::test_that("load_producer_artefact() reads RDS files", {
  data_example <-
    tibble::tibble(a = 1:2)

  path_rds <-
    base::file.path(withr::local_tempdir(), "example.rds")

  base::saveRDS(object = data_example, file = path_rds)

  res <-
    load_producer_artefact(
      data_files = tibble::tibble(
        file_name = "example.rds",
        path = path_rds,
        format = "rds"
      )
    )

  testthat::expect_equal(res, list(example.rds = data_example))
})

testthat::test_that("load_producer_artefact() reads csv files", {
  path_csv <-
    here::here(
      "Data", "Contracts", "fixtures", "valid", "trait_unit_conversions",
      "unit_conversions.csv"
    )

  contract <-
    load_producer_contract(
      path_contract = here::here(
        "Data", "Contracts", "trait_unit_conversions.yml"
      )
    )

  res <-
    load_producer_artefact(
      data_files = tibble::tibble(
        file_name = "unit_conversions.csv",
        path = path_csv,
        format = "csv"
      ),
      contract = contract
    )

  # With the contract's classes, the file reads back as it was built
  testthat::expect_identical(
    res,
    build_trait_unit_conversions_fixture(contract = contract)
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_artefact() validates its input", {
  testthat::expect_error(
    load_producer_artefact(
      data_files = tibble::tibble(
        file_name = "example.txt",
        path = "example.txt",
        format = "txt"
      )
    ),
    regexp = "txt"
  )

  # A csv file needs the column classes of its contract
  testthat::expect_error(
    load_producer_artefact(
      data_files = tibble::tibble(
        file_name = "example.csv",
        path = "example.csv",
        format = "csv"
      )
    ),
    regexp = "contract"
  )

  testthat::expect_error(
    load_producer_artefact(data_files = tibble::tibble(path = "x")),
    regexp = "format"
  )
})
