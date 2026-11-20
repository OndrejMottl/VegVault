#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_release_file() downloads a missing file", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  data_pinned <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    ) |>
    dplyr::pull(release_files) |>
    purrr::chuck(1L)

  dir_cache <-
    withr::local_tempdir()

  res <-
    resolve_release_file(
      file_name = dplyr::pull(data_pinned, file_name),
      sha256 = dplyr::pull(data_pinned, sha256),
      dir_cache = dir_cache,
      url_template = purrr::chuck(list_fixture, "url_template"),
      repository = "OndrejMottl/VegVault-Vegetation_data",
      tag = "v2.0.0",
      directory = "Outputs/Data"
    )

  testthat::expect_equal(
    res,
    base::file.path(
      dir_cache,
      dplyr::pull(data_pinned, sha256),
      dplyr::pull(data_pinned, file_name)
    )
  )

  testthat::expect_true(base::file.exists(res))
})


#----------------------------------------------------------#
# Functionality -----
#----------------------------------------------------------#

testthat::test_that("resolve_release_file() reuses and repairs the cache", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  data_pinned <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    ) |>
    dplyr::pull(release_files) |>
    purrr::chuck(1L)

  dir_cache <-
    withr::local_tempdir()

  path_cached <-
    base::file.path(
      dir_cache,
      dplyr::pull(data_pinned, sha256),
      dplyr::pull(data_pinned, file_name)
    )

  # A broken cached copy is downloaded again
  base::dir.create(base::dirname(path_cached), recursive = TRUE)

  base::writeBin(object = base::charToRaw("broken"), con = path_cached)

  resolve_release_file(
    file_name = dplyr::pull(data_pinned, file_name),
    sha256 = dplyr::pull(data_pinned, sha256),
    dir_cache = dir_cache,
    url_template = purrr::chuck(list_fixture, "url_template"),
    repository = "OndrejMottl/VegVault-Vegetation_data",
    tag = "v2.0.0",
    directory = "Outputs/Data"
  )

  testthat::expect_equal(
    compute_file_sha256(path_file = path_cached),
    dplyr::pull(data_pinned, sha256)
  )

  # A good cached copy is used without the releases
  base::unlink(purrr::chuck(list_fixture, "dir_remote"), recursive = TRUE)

  testthat::expect_equal(
    resolve_release_file(
      file_name = dplyr::pull(data_pinned, file_name),
      sha256 = dplyr::pull(data_pinned, sha256),
      dir_cache = dir_cache,
      url_template = purrr::chuck(list_fixture, "url_template"),
      repository = "OndrejMottl/VegVault-Vegetation_data",
      tag = "v2.0.0",
      directory = "Outputs/Data"
    ),
    path_cached
  )
})
