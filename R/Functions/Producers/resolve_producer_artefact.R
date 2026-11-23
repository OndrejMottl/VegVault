#' @title Resolve the files of a pinned producer artefact
#' @description
#' Find the local files of one artefact of the producer pin manifest: the
#' explicit files in the sibling producer checkout (`dev` mode), or the
#' pinned release files, downloaded into the cache and checked against
#' their checksums (`release` mode).
#' @param data_manifest
#' A tibble as returned by `load_producer_manifest()`.
#' @param artefact_id
#' Character scalar. The artefact to resolve.
#' @param mode
#' Character scalar. `"dev"` or `"release"` (`producers: mode` of
#' `config.yml`).
#' @param dir_dev_root
#' Character scalar. The folder holding the sibling producer checkouts,
#' each named like its repository without the owner. Used in `dev` mode.
#' @param dir_cache
#' Character scalar. The download cache; files go to
#' `<dir_cache>/<sha256>/<file_name>`. Used in `release` mode.
#' @param url_template
#' Character scalar. The URL template of the release files (see
#' `build_release_url()`). Used in `release` mode.
#' @return
#' A tibble with one row per file of the artefact and the columns
#' `artefact_id`, `mode`, `tag` (`NA` in `dev` mode), `file_name`, `path`,
#' `size` (bytes), `sha256` and `format` (`"qs2"` for `.qs`, `"rds"` for
#' `.rds`).
#' @details
#' In `dev` mode the files listed under `dev` are read from
#' `<dir_dev_root>/<repository name>/<dev_directory>/`, the entry's own
#' `dev: directory` or else the contract's folder; nothing is downloaded,
#' and their size and checksum are recorded as found, so that a dev build
#' documents what it used. In `release` mode a file already in the cache
#' with the pinned checksum is reused; otherwise it is downloaded by
#' `save_release_file()`. Aborts, naming the artefact, for an unknown
#' artefact, a placeholder (no dev files, or no release tag), a missing
#' local file, a failed download, a checksum or size mismatch, or a file
#' type other than `.qs` and `.rds`.
#' @examples
#' \dontrun{
#' data_files_splot <-
#'   resolve_producer_artefact(
#'     data_manifest = data_manifest,
#'     artefact_id = "splot_plots",
#'     mode = "release",
#'     dir_dev_root = here::here(".."),
#'     dir_cache = base::file.path(path_data_storage, "Producers"),
#'     url_template = load_config_value(
#'       value = c("producers", "release_url_template")
#'     )
#'   )
#' }
resolve_producer_artefact <- function(
  data_manifest,
  artefact_id,
  mode,
  dir_dev_root,
  dir_cache,
  url_template
) {
  validate_data_columns(
    data_source = data_manifest,
    vec_columns_required = c(
      "artefact_id", "repository", "directory", "release_tag",
      "release_files", "dev_files", "dev_directory"
    ),
    name_argument = "data_manifest"
  )

  assertthat::assert_that(
    base::is.character(artefact_id),
    base::length(artefact_id) == 1L,
    !base::is.na(artefact_id),
    msg = "`artefact_id` must be a character scalar."
  )

  assertthat::assert_that(
    base::is.character(mode),
    base::length(mode) == 1L,
    mode %in% c("dev", "release"),
    msg = "`mode` must be \"dev\" or \"release\"."
  )

  sel_artefact_id <- artefact_id

  data_entry <-
    data_manifest |>
    dplyr::filter(artefact_id == sel_artefact_id)

  if (
    base::nrow(data_entry) != 1L
  ) {
    cli::cli_abort(
      "{.val {artefact_id}} is not in the producer manifest."
    )
  }

  repository <-
    dplyr::pull(data_entry, repository)

  directory <-
    dplyr::pull(data_entry, directory)

  data_files_found <-
    if (
      mode == "dev"
    ) {
      assertthat::assert_that(
        base::is.character(dir_dev_root),
        base::length(dir_dev_root) == 1L,
        !base::is.na(dir_dev_root),
        msg = "`dir_dev_root` must be a character scalar."
      )

      vec_file_names <-
        purrr::chuck(dplyr::pull(data_entry, dev_files), 1L)

      if (
        base::length(vec_file_names) == 0L
      ) {
        cli::cli_abort(
          "{.val {artefact_id}} has no dev files in the producer manifest
          (a placeholder)."
        )
      }

      # The sibling checkout is named like the repository, without owner
      vec_paths <-
        base::file.path(
          dir_dev_root,
          base::basename(repository),
          dplyr::pull(data_entry, dev_directory),
          vec_file_names
        )

      # A folder with the name of a file does not count as that file
      vec_is_file <-
        base::file.exists(vec_paths) & !base::dir.exists(vec_paths)

      vec_missing <-
        vec_file_names[!vec_is_file]

      if (
        base::length(vec_missing) > 0L
      ) {
        cli::cli_abort(
          c(
            "Dev files of {.val {artefact_id}} not found in the sibling
            checkout:",
            rlang::set_names(vec_missing, "x")
          )
        )
      }

      tibble::tibble(
        artefact_id = artefact_id,
        mode = "dev",
        tag = NA_character_,
        file_name = vec_file_names,
        path = vec_paths,
        size = base::as.numeric(base::file.size(vec_paths)),
        sha256 = purrr::map_chr(
          .x = vec_paths,
          .f = ~ compute_file_sha256(path_file = .x)
        )
      )
    } else {
      tag <-
        dplyr::pull(data_entry, release_tag)

      if (
        base::is.na(tag)
      ) {
        cli::cli_abort(
          "{.val {artefact_id}} is a placeholder in the producer manifest:
          it has no release tag."
        )
      }

      if (
        !is_release_tag(tag)
      ) {
        cli::cli_abort(
          "{.val {tag}} of {.val {artefact_id}} is not a release tag such as
          {.val v2.0.0}."
        )
      }

      data_pinned <-
        purrr::chuck(dplyr::pull(data_entry, release_files), 1L)

      if (
        base::nrow(data_pinned) == 0L
      ) {
        cli::cli_abort(
          "{.val {artefact_id}} has a release tag but no files in the
          producer manifest."
        )
      }

      assertthat::assert_that(
        base::is.character(dir_cache),
        base::length(dir_cache) == 1L,
        !base::is.na(dir_cache),
        base::is.character(url_template),
        base::length(url_template) == 1L,
        msg = "`dir_cache` and `url_template` must be character scalars."
      )

      # The cache is keyed by checksum, so a pinned file is fetched once;
      #   the cause of an error names the file, this message the artefact
      vec_paths <-
        base::tryCatch(
          expr = purrr::map2_chr(
            .x = dplyr::pull(data_pinned, file_name),
            .y = dplyr::pull(data_pinned, sha256),
            .f = ~ resolve_release_file(
              file_name = .x,
              sha256 = .y,
              dir_cache = dir_cache,
              url_template = url_template,
              repository = repository,
              tag = tag,
              directory = directory
            )
          ),
          error = function(error) {
            cli::cli_abort(
              "Release files of {.val {artefact_id}} could not be resolved.",
              parent = error
            )
          }
        )

      vec_sizes <-
        base::as.numeric(base::file.size(vec_paths))

      vec_size_differs <-
        dplyr::pull(data_pinned, file_name)[
          vec_sizes != dplyr::pull(data_pinned, size)
        ]

      if (
        base::length(vec_size_differs) > 0L
      ) {
        cli::cli_abort(
          c(
            "Release files of {.val {artefact_id}} differ in size from the
            producer manifest:",
            rlang::set_names(vec_size_differs, "x")
          )
        )
      }

      tibble::tibble(
        artefact_id = artefact_id,
        mode = "release",
        tag = tag,
        file_name = dplyr::pull(data_pinned, file_name),
        path = vec_paths,
        size = vec_sizes,
        sha256 = dplyr::pull(data_pinned, sha256)
      )
    }

  vec_extensions <-
    stringr::str_extract(
      dplyr::pull(data_files_found, file_name),
      "[.][A-Za-z0-9]+$"
    )

  vec_unsupported <-
    dplyr::pull(data_files_found, file_name)[
      !vec_extensions %in% c(".qs", ".rds")
    ]

  if (
    base::length(vec_unsupported) > 0L
  ) {
    cli::cli_abort(
      c(
        "Files of {.val {artefact_id}} are neither {.val .qs} nor
        {.val .rds}:",
        rlang::set_names(vec_unsupported, "x")
      )
    )
  }

  res <-
    data_files_found |>
    dplyr::mutate(
      format = dplyr::if_else(vec_extensions == ".qs", "qs2", "rds")
    )

  return(res)
}
