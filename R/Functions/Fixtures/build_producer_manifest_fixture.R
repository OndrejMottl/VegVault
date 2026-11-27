#' @title Build a producer pin manifest with local stand-ins for tests
#' @description
#' Copy the valid contract fixtures of some artefacts into a local stand-in
#' for the producer releases and into a stand-in for the sibling producer
#' checkouts, and write a pin manifest that pins them, so that the
#' resolver can be tested without network access.
#' @param dir_root
#' Character scalar. An existing, empty folder that receives everything.
#' @param vec_contract_ids
#' Character vector of contract ids with valid fixtures in
#' `<dir_contracts>/fixtures/valid/`. Default: `splot_plots` (one file)
#' and `bien_traits` (three partitions).
#' @param tag
#' Character scalar. The release tag of every artefact.
#' @param dir_contracts
#' Character scalar. The contract folder. Default: `Data/Contracts`.
#' @return
#' A named list: `path_manifest` (the manifest file), `dir_dev_root` (the
#' stand-in for the folder of the sibling checkouts, holding
#' `<repository name>/<directory>/<files>`), `dir_remote` (the stand-in for
#' the releases, holding `<repository>/<tag>/<directory>/<files>`) and
#' `url_template` (a `file://` URL template for `build_release_url()`).
#' @details
#' Each artefact gets its release tag, the name, size and SHA-256 of every
#' file, and the same file names as its `dev` files. The output depends
#' only on the fixtures.
#' @examples
#' \dontrun{
#' list_fixture <-
#'   build_producer_manifest_fixture(dir_root = withr::local_tempdir())
#' }
build_producer_manifest_fixture <- function(
  dir_root,
  vec_contract_ids = c("splot_plots", "bien_traits"),
  tag = "v2.0.0",
  dir_contracts = here::here("Data", "Contracts")
) {
  assertthat::assert_that(
    base::is.character(dir_root),
    base::length(dir_root) == 1L,
    base::dir.exists(dir_root),
    base::length(
      base::list.files(path = dir_root, all.files = TRUE, no.. = TRUE)
    ) == 0L,
    msg = "`dir_root` must be an existing, empty folder."
  )

  assertthat::assert_that(
    base::is.character(vec_contract_ids),
    base::length(vec_contract_ids) > 0L,
    !base::anyNA(vec_contract_ids),
    msg = "`vec_contract_ids` must be a non-empty character vector."
  )

  assertthat::assert_that(
    is_release_tag(tag),
    msg = "`tag` must be a release tag such as v2.0.0."
  )

  dir_dev_root <-
    base::file.path(dir_root, "dev")

  dir_remote <-
    base::file.path(dir_root, "remote")

  list_entries <-
    purrr::map(
      .x = vec_contract_ids,
      .f = ~ {
        contract_id <- .x

        contract <-
          load_producer_contract(
            path_contract = base::file.path(
              dir_contracts,
              stringr::str_c(contract_id, ".yml")
            )
          )

        repository <-
          purrr::chuck(contract, "producer", "repository")

        directory <-
          purrr::chuck(contract, "producer", "directory")

        vec_paths_fixture <-
          base::list.files(
            path = base::file.path(
              dir_contracts, "fixtures", "valid", contract_id
            ),
            full.names = TRUE
          ) |>
          base::sort(method = "radix")

        # The sibling checkout is named like the repository, without owner
        dir_dev <-
          base::file.path(dir_dev_root, base::basename(repository), directory)

        dir_release <-
          base::file.path(dir_remote, repository, tag, directory)

        base::dir.create(dir_dev, recursive = TRUE, showWarnings = FALSE)

        base::dir.create(dir_release, recursive = TRUE, showWarnings = FALSE)

        base::file.copy(from = vec_paths_fixture, to = dir_dev)

        base::file.copy(from = vec_paths_fixture, to = dir_release)

        list_files <-
          purrr::map(
            .x = vec_paths_fixture,
            .f = ~ list(
              file_name = base::basename(.x),
              size = base::file.size(.x),
              sha256 = compute_file_sha256(path_file = .x)
            )
          )

        list(
          artefact_id = contract_id,
          contract_version = purrr::chuck(contract, "contract_version"),
          release = list(tag = tag, files = list_files),
          dev = list(files = base::as.list(base::basename(vec_paths_fixture)))
        )
      }
    )

  path_manifest <-
    base::file.path(dir_root, "producer_manifest.yml")

  yaml::write_yaml(
    x = list(manifest_version = 1L, artefacts = list_entries),
    file = path_manifest
  )

  # file:///C:/... on Windows, file:///tmp/... elsewhere
  url_template <-
    stringr::str_c(
      "file:///",
      base::normalizePath(dir_remote, winslash = "/") |>
        stringr::str_remove("^/"),
      "/{repository}/{tag}/{directory}/{file_name}"
    )

  res <-
    list(
      path_manifest = path_manifest,
      dir_dev_root = base::normalizePath(dir_dev_root, winslash = "/"),
      dir_remote = base::normalizePath(dir_remote, winslash = "/"),
      url_template = url_template
    )

  return(res)
}
