#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_manifest() reads a pinned manifest", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  res <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c(
      "artefact_id", "contract_version", "path_contract", "repository",
      "directory", "note", "release_tag", "release_files", "dev_files"
    )
  )

  testthat::expect_equal(
    dplyr::pull(res, artefact_id),
    c("splot_plots", "bien_traits")
  )

  testthat::expect_equal(
    dplyr::pull(res, repository),
    c("OndrejMottl/VegVault-Vegetation_data", "OndrejMottl/VegVault-Trait_data")
  )

  testthat::expect_equal(dplyr::pull(res, release_tag), c("v2.0.0", "v2.0.0"))

  data_files_bien <-
    purrr::chuck(dplyr::pull(res, release_files), 2L)

  testthat::expect_named(data_files_bien, c("file_name", "size", "sha256"))

  testthat::expect_equal(base::nrow(data_files_bien), 3L)

  testthat::expect_length(purrr::chuck(dplyr::pull(res, dev_files), 2L), 3L)
})

testthat::test_that("load_producer_manifest() reads the project manifest", {
  res <-
    load_producer_manifest(
      path_manifest = here::here("Data", "Producers", "producer_manifest.yml")
    )

  vec_contract_ids <-
    base::list.files(
      path = here::here("Data", "Contracts"),
      pattern = "[.]yml$"
    ) |>
    stringr::str_remove("[.]yml$")

  testthat::expect_setequal(dplyr::pull(res, artefact_id), vec_contract_ids)
})

testthat::test_that("load_producer_manifest() needs every contract", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  # The fixture pins two of the contracts
  res_error <-
    testthat::expect_error(
      load_producer_manifest(
        path_manifest = purrr::chuck(list_fixture, "path_manifest")
      ),
      regexp = "not valid"
    )

  testthat::expect_match(
    base::conditionMessage(res_error),
    "no\\s+entry\\s+for\\s+the\\s+contract\\s+'bien_plots'"
  )

  testthat::expect_no_match(
    base::conditionMessage(res_error),
    "no\\s+entry\\s+for\\s+the\\s+contract\\s+'splot_plots'"
  )
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("load_producer_manifest() reports every problem", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  list_manifest <-
    yaml::read_yaml(file = purrr::chuck(list_fixture, "path_manifest"))

  list_manifest_broken <-
    purrr::modify_in(
      .x = list_manifest,
      .where = list("artefacts", 1L, "release", "tag"),
      .f = ~ "main"
    ) |>
    purrr::modify_in(
      .where = list("artefacts", 2L, "release", "files", 1L, "sha256"),
      .f = ~ "abc"
    )

  path_broken <-
    base::file.path(withr::local_tempdir(), "producer_manifest.yml")

  yaml::write_yaml(x = list_manifest_broken, file = path_broken)

  res_error <-
    testthat::expect_error(
      load_producer_manifest(path_manifest = path_broken),
      regexp = "not valid"
    )

  vec_message <-
    base::conditionMessage(res_error)

  testthat::expect_match(vec_message, "splot_plots")

  testthat::expect_match(vec_message, "bien_traits")
})

testthat::test_that("load_producer_manifest() needs unique artefacts", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  list_manifest <-
    yaml::read_yaml(file = purrr::chuck(list_fixture, "path_manifest"))

  list_manifest_twice <-
    purrr::modify_in(
      .x = list_manifest,
      .where = "artefacts",
      .f = ~ c(.x, .x[1L])
    )

  path_twice <-
    base::file.path(withr::local_tempdir(), "producer_manifest.yml")

  yaml::write_yaml(x = list_manifest_twice, file = path_twice)

  testthat::expect_error(
    load_producer_manifest(path_manifest = path_twice),
    regexp = "more than once"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("load_producer_manifest() checks the top level", {
  path_manifest <-
    base::file.path(withr::local_tempdir(), "producer_manifest.yml")

  yaml::write_yaml(
    x = list(manifest_version = 2L, artefacts = list(), extra = 1L),
    file = path_manifest
  )

  res_error <-
    testthat::expect_error(
      load_producer_manifest(path_manifest = path_manifest),
      regexp = "manifest_version"
    )

  testthat::expect_match(base::conditionMessage(res_error), "extra")

  testthat::expect_error(
    load_producer_manifest(
      path_manifest = base::file.path(withr::local_tempdir(), "none.yml")
    ),
    regexp = "path_manifest"
  )
})

testthat::test_that("load_producer_manifest() reports malformed shapes", {
  dir_manifest <-
    withr::local_tempdir()

  # Entries written as names instead of maps
  path_strings <-
    base::file.path(dir_manifest, "strings.yml")

  yaml::write_yaml(
    x = list(manifest_version = 1L, artefacts = list("splot_plots")),
    file = path_strings
  )

  testthat::expect_error(
    load_producer_manifest(
      path_manifest = path_strings,
      flag_require_all_contracts = FALSE
    ),
    regexp = "artefacts\\[1\\]:\\s+must\\s+be\\s+a\\s+map"
  )

  # A version that is not a number, without a coercion warning
  path_version <-
    base::file.path(dir_manifest, "version.yml")

  yaml::write_yaml(
    x = list(manifest_version = "abc", artefacts = list()),
    file = path_version
  )

  testthat::expect_no_warning(
    testthat::expect_error(
      load_producer_manifest(path_manifest = path_version),
      regexp = "manifest_version"
    )
  )

  # Text that is not YAML, reported with the file name
  path_broken <-
    base::file.path(dir_manifest, "broken_manifest.yml")

  base::writeLines(text = "artefacts: [a, b", con = path_broken)

  testthat::expect_error(
    load_producer_manifest(path_manifest = path_broken),
    regexp = "broken_manifest.yml"
  )
})
