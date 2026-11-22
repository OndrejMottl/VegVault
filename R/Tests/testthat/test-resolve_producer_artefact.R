#----------------------------------------------------------#
# Outputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_producer_artefact() finds the dev files", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  data_manifest <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    )

  res <-
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "bien_traits",
      mode = "dev",
      dir_dev_root = purrr::chuck(list_fixture, "dir_dev_root"),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    )

  testthat::expect_s3_class(res, "tbl_df")

  testthat::expect_named(
    res,
    c(
      "artefact_id", "mode", "tag", "file_name", "path", "size", "sha256",
      "format"
    )
  )

  testthat::expect_equal(base::nrow(res), 3L)

  testthat::expect_equal(base::unique(dplyr::pull(res, mode)), "dev")

  testthat::expect_true(base::all(base::is.na(dplyr::pull(res, tag))))

  testthat::expect_true(base::all(base::file.exists(dplyr::pull(res, path))))

  testthat::expect_true(
    base::all(
      stringr::str_starts(
        dplyr::pull(res, path),
        purrr::chuck(list_fixture, "dir_dev_root")
      )
    )
  )

  testthat::expect_equal(base::unique(dplyr::pull(res, format)), "qs2")

  # The fixture copies are the release files, so the checksums agree
  testthat::expect_equal(
    dplyr::pull(res, sha256),
    dplyr::pull(
      purrr::chuck(dplyr::pull(data_manifest, release_files), 2L),
      sha256
    )
  )
})

testthat::test_that("resolve_producer_artefact() fetches release files", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  data_manifest <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    )

  dir_cache <-
    withr::local_tempdir()

  res <-
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "splot_plots",
      mode = "release",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = dir_cache,
      url_template = purrr::chuck(list_fixture, "url_template")
    )

  testthat::expect_equal(dplyr::pull(res, tag), "v2.0.0")

  testthat::expect_equal(dplyr::pull(res, mode), "release")

  data_pinned <-
    purrr::chuck(dplyr::pull(data_manifest, release_files), 1L)

  testthat::expect_equal(
    dplyr::pull(res, path),
    base::file.path(
      dir_cache,
      dplyr::pull(data_pinned, sha256),
      dplyr::pull(data_pinned, file_name)
    )
  )

  testthat::expect_true(base::file.exists(dplyr::pull(res, path)))

  # Without the releases, the cached file is used again
  base::unlink(purrr::chuck(list_fixture, "dir_remote"), recursive = TRUE)

  res_cached <-
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "splot_plots",
      mode = "release",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = dir_cache,
      url_template = purrr::chuck(list_fixture, "url_template")
    )

  testthat::expect_equal(res_cached, res)
})


#----------------------------------------------------------#
# Edge cases -----
#----------------------------------------------------------#

testthat::test_that("resolve_producer_artefact() refuses placeholders", {
  path_placeholder <-
    base::file.path(withr::local_tempdir(), "producer_manifest.yml")

  yaml::write_yaml(
    x = list(
      manifest_version = 1L,
      artefacts = list(
        list(
          artefact_id = "splot_plots",
          contract_version = load_producer_contract(
            path_contract = here::here("Data", "Contracts", "splot_plots.yml")
          ) |>
            purrr::chuck("contract_version"),
          release = list(tag = NULL, files = list()),
          dev = list(files = list())
        )
      )
    ),
    file = path_placeholder
  )

  data_manifest <-
    load_producer_manifest(
      path_manifest = path_placeholder,
      flag_require_all_contracts = FALSE
    )

  testthat::expect_true(base::is.na(dplyr::pull(data_manifest, release_tag)))

  testthat::expect_error(
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "splot_plots",
      mode = "release",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = withr::local_tempdir(),
      url_template = "https://host/{repository}/{tag}/{file_name}"
    ),
    regexp = "splot_plots.*placeholder"
  )

  testthat::expect_error(
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "splot_plots",
      mode = "dev",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = withr::local_tempdir(),
      url_template = "https://host/{repository}/{tag}/{file_name}"
    ),
    regexp = "splot_plots.*no dev files"
  )
})

testthat::test_that("resolve_producer_artefact() refuses a changed byte", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  data_manifest <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    )

  path_remote <-
    base::list.files(
      path = purrr::chuck(list_fixture, "dir_remote"),
      pattern = "^data_splot_",
      recursive = TRUE,
      full.names = TRUE
    )

  vec_bytes <-
    base::readBin(path_remote, what = "raw", n = base::file.size(path_remote))

  vec_bytes_changed <-
    c(vec_bytes[-base::length(vec_bytes)], base::as.raw(0L))

  base::writeBin(object = vec_bytes_changed, con = path_remote)

  testthat::expect_error(
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "splot_plots",
      mode = "release",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    ),
    regexp = "checksum"
  )
})

testthat::test_that("resolve_producer_artefact() refuses a wrong size", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  # The checksum agrees, the size in the manifest does not
  data_manifest <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    ) |>
    dplyr::mutate(
      release_files = purrr::map(
        .x = release_files,
        .f = ~ dplyr::mutate(.x, size = size + 1)
      )
    )

  testthat::expect_error(
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "splot_plots",
      mode = "release",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    ),
    regexp = "differ\\s+in\\s+size"
  )
})

testthat::test_that("resolve_producer_artefact() refuses a dev folder", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  data_manifest <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    )

  # A folder with the name of a dev file is not that file
  path_dev <-
    base::list.files(
      path = purrr::chuck(list_fixture, "dir_dev_root"),
      pattern = "^data_splot_",
      recursive = TRUE,
      full.names = TRUE
    )

  base::unlink(path_dev)

  base::dir.create(path_dev)

  testthat::expect_error(
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "splot_plots",
      mode = "dev",
      dir_dev_root = purrr::chuck(list_fixture, "dir_dev_root"),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    ),
    regexp = "splot_plots.*not\\s+found"
  )
})

testthat::test_that("resolve_producer_artefact() needs files and tags", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  data_manifest <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    )

  # A dev file that is not in the sibling checkout is never downloaded
  base::unlink(purrr::chuck(list_fixture, "dir_dev_root"), recursive = TRUE)

  testthat::expect_error(
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "splot_plots",
      mode = "dev",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    ),
    regexp = "splot_plots.*not found"
  )

  # A branch in place of a tag
  data_manifest_branch <-
    dplyr::mutate(data_manifest, release_tag = "main")

  testthat::expect_error(
    resolve_producer_artefact(
      data_manifest = data_manifest_branch,
      artefact_id = "splot_plots",
      mode = "release",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = withr::local_tempdir(),
      url_template = purrr::chuck(list_fixture, "url_template")
    ),
    regexp = "release tag"
  )

  # A release file missing at the tag; the message names the artefact and
  #   the cause the file
  base::unlink(purrr::chuck(list_fixture, "dir_remote"), recursive = TRUE)

  res_error <-
    testthat::expect_error(
      resolve_producer_artefact(
        data_manifest = data_manifest,
        artefact_id = "splot_plots",
        mode = "release",
        dir_dev_root = withr::local_tempdir(),
        dir_cache = withr::local_tempdir(),
        url_template = purrr::chuck(list_fixture, "url_template")
      ),
      regexp = "splot_plots"
    )

  testthat::expect_match(
    base::conditionMessage(res_error),
    "could\\s+not\\s+be\\s+downloaded"
  )
})


#----------------------------------------------------------#
# Inputs -----
#----------------------------------------------------------#

testthat::test_that("resolve_producer_artefact() validates its arguments", {
  list_fixture <-
    build_producer_manifest_fixture(dir_root = withr::local_tempdir())

  data_manifest <-
    load_producer_manifest(
      path_manifest = purrr::chuck(list_fixture, "path_manifest"),
      flag_require_all_contracts = FALSE
    )

  testthat::expect_error(
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "unknown",
      mode = "dev",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = withr::local_tempdir(),
      url_template = "https://host/{repository}/{tag}/{file_name}"
    ),
    regexp = "not in the producer manifest"
  )

  testthat::expect_error(
    resolve_producer_artefact(
      data_manifest = data_manifest,
      artefact_id = "splot_plots",
      mode = "test",
      dir_dev_root = withr::local_tempdir(),
      dir_cache = withr::local_tempdir(),
      url_template = "https://host/{repository}/{tag}/{file_name}"
    ),
    regexp = "mode"
  )
})
