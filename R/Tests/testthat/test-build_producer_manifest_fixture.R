#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_manifest_fixture() builds the layout", {
  dir_root <-
    withr::local_tempdir()

  res <-
    build_producer_manifest_fixture(dir_root = dir_root)

  testthat::expect_named(
    res,
    c("path_manifest", "dir_dev_root", "dir_remote", "url_template")
  )

  testthat::expect_true(base::file.exists(purrr::chuck(res, "path_manifest")))

  file_splot <-
    "data_splot_2000-01-01__000608b7c919d261ab30308e780dc9aa__.qs"

  path_dev <-
    base::file.path(
      purrr::chuck(res, "dir_dev_root"),
      "VegVault-Vegetation_data", "Outputs/Data", file_splot
    )

  path_remote <-
    base::file.path(
      purrr::chuck(res, "dir_remote"),
      "OndrejMottl/VegVault-Vegetation_data", "v2.0.0", "Outputs/Data",
      file_splot
    )

  testthat::expect_true(base::file.exists(path_dev))

  testthat::expect_true(base::file.exists(path_remote))

  testthat::expect_true(
    stringr::str_starts(purrr::chuck(res, "url_template"), "file:///")
  )

  testthat::expect_true(
    stringr::str_ends(
      purrr::chuck(res, "url_template"),
      stringr::fixed("/{repository}/{tag}/{directory}/{file_name}")
    )
  )
})

testthat::test_that("build_producer_manifest_fixture() pins the files", {
  res <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  list_manifest <-
    yaml::read_yaml(file = purrr::chuck(res, "path_manifest"))

  list_entry_bien <-
    purrr::chuck(list_manifest, "artefacts", 2L)

  testthat::expect_equal(
    purrr::chuck(list_entry_bien, "artefact_id"),
    "bien_traits"
  )

  testthat::expect_equal(
    purrr::chuck(list_entry_bien, "release", "tag"),
    "v2.0.0"
  )

  list_files <-
    purrr::chuck(list_entry_bien, "release", "files")

  testthat::expect_length(list_files, 3L)

  list_file_first <-
    purrr::chuck(list_files, 1L)

  path_remote_first <-
    base::file.path(
      purrr::chuck(res, "dir_remote"),
      "OndrejMottl/VegVault-Trait_data", "v2.0.0", "Outputs/Data",
      purrr::chuck(list_file_first, "file_name")
    )

  testthat::expect_equal(
    purrr::chuck(list_file_first, "sha256"),
    compute_file_sha256(path_file = path_remote_first)
  )

  testthat::expect_equal(
    purrr::chuck(list_file_first, "size"),
    base::file.size(path_remote_first)
  )

  testthat::expect_equal(
    base::unlist(purrr::chuck(list_entry_bien, "dev", "files")),
    purrr::map_chr(.x = list_files, .f = ~ purrr::chuck(.x, "file_name"))
  )
})

testthat::test_that("build_producer_manifest_fixture() is deterministic", {
  res_first <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  res_second <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  testthat::expect_equal(
    base::readLines(purrr::chuck(res_first, "path_manifest")),
    base::readLines(purrr::chuck(res_second, "path_manifest"))
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("build_producer_manifest_fixture() needs an empty root", {
  dir_root <-
    withr::local_tempdir()

  base::writeLines(text = "keep", con = base::file.path(dir_root, "x.txt"))

  testthat::expect_error(
    build_producer_manifest_fixture(dir_root = dir_root),
    regexp = "dir_root"
  )

  testthat::expect_error(
    build_producer_manifest_fixture(
      dir_root = withr::local_tempdir(),
      tag = "main"
    ),
    regexp = "tag"
  )
})
