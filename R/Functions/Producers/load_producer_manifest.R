#' @title Load the producer pin manifest
#' @description
#' Read the manifest that pins every producer artefact VegVault reads,
#' check it against its format and against the artefact contracts, and
#' return one row per artefact.
#' @param path_manifest
#' Character scalar. Path of the manifest; the project keeps it at
#' `producers: manifest` of `config.yml`
#' (`Data/Producers/producer_manifest.yml`).
#' @param dir_contracts
#' Character scalar. The folder of the contracts. Default:
#' `Data/Contracts`.
#' @param flag_require_all_contracts
#' Logical scalar. Whether every contract in `dir_contracts` that is not
#' retired needs an entry in the manifest. Default: `TRUE`. Test
#' manifests that pin only some artefacts set it to `FALSE`.
#' @return
#' A tibble with one row per artefact and the columns `artefact_id`,
#' `contract_version`, `path_contract`, `repository` and `directory` (from
#' the contract), `note` (character, `NA` when absent), `release_tag`
#' (character, `NA` for a placeholder), `release_files` (a list of tibbles
#' with `file_name`, `size` and `sha256`), `dev_files` (a list of
#' character vectors of file names) and `dev_directory` (the folder of the
#' dev files in the producer checkout: the entry's `dev: directory`, or the
#' contract's `directory` when it has none).
#' @details
#' The manifest is a YAML map with `manifest_version` (1) and `artefacts`,
#' a list of entries, each a map checked by
#' `diagnose_producer_manifest_entry()`. Artefact ids must be unique. With
#' `flag_require_all_contracts = TRUE`, a contract whose `status` is not
#' `retired` and that has no entry is a problem. Every problem of the
#' whole manifest is reported at once, then the function aborts.
#' @examples
#' \dontrun{
#' data_manifest <-
#'   load_producer_manifest(
#'     path_manifest = here::here("Data", "Producers", "producer_manifest.yml")
#'   )
#' }
load_producer_manifest <- function(
  path_manifest,
  dir_contracts = here::here("Data", "Contracts"),
  flag_require_all_contracts = TRUE
) {
  assertthat::assert_that(
    base::is.character(path_manifest),
    base::length(path_manifest) == 1L,
    !base::is.na(path_manifest),
    base::file.exists(path_manifest),
    !base::dir.exists(path_manifest),
    msg = "`path_manifest` must be the path of an existing manifest file."
  )

  assertthat::assert_that(
    base::is.character(dir_contracts),
    base::length(dir_contracts) == 1L,
    base::dir.exists(dir_contracts),
    msg = "`dir_contracts` must be an existing folder."
  )

  assertthat::assert_that(
    base::is.logical(flag_require_all_contracts),
    base::length(flag_require_all_contracts) == 1L,
    !base::is.na(flag_require_all_contracts),
    msg = "`flag_require_all_contracts` must be TRUE or FALSE."
  )

  file_manifest <-
    base::basename(path_manifest)

  list_raw <-
    base::tryCatch(
      yaml::read_yaml(file = path_manifest),
      error = function(error) {
        cli::cli_abort(
          "The producer manifest {.file {file_manifest}} is not valid YAML.",
          parent = error
        )
      }
    )

  if (
    !base::is.list(list_raw) || base::is.null(base::names(list_raw))
  ) {
    cli::cli_abort(
      "The producer manifest {.file {file_manifest}} must be a YAML map."
    )
  }

  vec_fields <-
    base::names(list_raw)

  value_version <-
    purrr::pluck(list_raw, "manifest_version")

  value_artefacts <-
    purrr::pluck(list_raw, "artefacts", .default = list())

  # `artefacts` must be a YAML sequence: an unnamed list, or a vector when
  #   every element is a scalar; a map is reported once and not checked
  #   further
  flag_artefacts_list <-
    base::is.null(base::names(value_artefacts)) &&
    (base::is.list(value_artefacts) || base::is.atomic(value_artefacts))

  list_artefacts <-
    if (
      flag_artefacts_list
    ) {
      base::as.list(value_artefacts)
    } else {
      list()
    }

  # Only entries that are YAML maps are diagnosed
  vec_is_map <-
    purrr::map_lgl(
      .x = list_artefacts,
      .f = ~ base::is.list(.x) && !base::is.null(base::names(.x))
    )

  # The id of each entry, or NA when it is not one text value
  vec_artefact_ids <-
    purrr::map_chr(
      .x = list_artefacts,
      .f = ~ {
        value_id <-
          if (
            base::is.list(.x)
          ) {
            purrr::pluck(.x, "artefact_id")
          } else {
            NULL
          }

        if (
          base::is.character(value_id) &&
            base::length(value_id) == 1L &&
            !base::is.na(value_id)
        ) {
          value_id
        } else {
          NA_character_
        }
      }
    )

  vec_ids_repeated <-
    vec_artefact_ids[
      base::duplicated(vec_artefact_ids) & !base::is.na(vec_artefact_ids)
    ] |>
    base::unique()

  #--------------------------------------------------#
  ## Contracts without an entry -----
  #--------------------------------------------------#

  vec_ids_missing <-
    if (
      flag_require_all_contracts
    ) {
      vec_paths_all <-
        base::list.files(
          path = dir_contracts,
          pattern = "[.]yml$",
          full.names = TRUE
        )

      vec_status <-
        purrr::map_chr(
          .x = vec_paths_all,
          .f = ~ load_producer_contract(path_contract = .x) |>
            purrr::chuck("status")
        )

      vec_paths_all[vec_status != "retired"] |>
        base::basename() |>
        stringr::str_remove("[.]yml$") |>
        base::setdiff(vec_artefact_ids)
    } else {
      base::character(0)
    }

  #--------------------------------------------------#
  ## Problems -----
  #--------------------------------------------------#

  vec_problems <-
    c(
      base::character(0),
      stringr::str_c(
        "missing field '",
        base::setdiff(c("manifest_version", "artefacts"), vec_fields),
        "'."
      ),
      stringr::str_c(
        "unknown field '",
        base::setdiff(vec_fields, c("manifest_version", "artefacts")),
        "'."
      ),
      # Compared without coercion, so a text value gives no warning
      if (
        !(
          base::identical(value_version, 1L) ||
            base::identical(value_version, 1)
        )
      ) {
        "manifest_version: must be 1."
      },
      if (
        !flag_artefacts_list
      ) {
        "artefacts: must be a list of entries."
      },
      if (
        flag_artefacts_list && base::length(list_artefacts) == 0L
      ) {
        "artefacts: must list at least one artefact."
      },
      stringr::str_c(
        "artefacts[", base::which(!vec_is_map),
        "]: must be a map with artefact_id, contract_version, release and ",
        "dev."
      ),
      stringr::str_c(
        "artefact_id '", vec_ids_repeated, "' is listed more than once."
      ),
      stringr::str_c(
        "artefacts: no entry for the contract '", vec_ids_missing, "'."
      ),
      purrr::map(
        .x = list_artefacts[vec_is_map],
        .f = ~ diagnose_producer_manifest_entry(
          list_entry = .x,
          dir_contracts = dir_contracts
        )
      ) |>
        base::unlist(use.names = FALSE)
    )

  if (
    base::length(vec_problems) > 0L
  ) {
    # Messages may quote templates with braces, which cli would read as
    #   glue expressions, so they are doubled
    vec_problems_escaped <-
      vec_problems |>
      stringr::str_replace_all(
        pattern = stringr::fixed("{"),
        replacement = "{{"
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed("}"),
        replacement = "}}"
      ) |>
      rlang::set_names("x")

    cli::cli_abort(
      c(
        "The producer manifest {.file {file_manifest}} is not valid.",
        vec_problems_escaped
      )
    )
  }

  #--------------------------------------------------#
  ## Table -----
  #--------------------------------------------------#

  vec_paths_contract <-
    base::file.path(dir_contracts, stringr::str_c(vec_artefact_ids, ".yml"))

  list_contracts <-
    purrr::map(
      .x = vec_paths_contract,
      .f = ~ load_producer_contract(path_contract = .x)
    )

  data_files_empty <-
    tibble::tibble(
      file_name = base::character(0),
      size = base::numeric(0),
      sha256 = base::character(0)
    )

  res <-
    tibble::tibble(
      artefact_id = vec_artefact_ids,
      contract_version = purrr::map_chr(
        .x = list_artefacts,
        .f = ~ base::as.character(purrr::chuck(.x, "contract_version"))
      ),
      path_contract = vec_paths_contract,
      repository = purrr::map_chr(
        .x = list_contracts,
        .f = ~ purrr::chuck(.x, "producer", "repository")
      ),
      directory = purrr::map_chr(
        .x = list_contracts,
        .f = ~ purrr::chuck(.x, "producer", "directory")
      ),
      note = purrr::map_chr(
        .x = list_artefacts,
        .f = ~ purrr::pluck(.x, "note", .default = NA_character_)
      ),
      release_tag = purrr::map_chr(
        .x = list_artefacts,
        .f = ~ purrr::pluck(.x, "release", "tag", .default = NA_character_)
      ),
      release_files = purrr::map(
        .x = list_artefacts,
        .f = ~ purrr::pluck(.x, "release", "files", .default = list()) |>
          purrr::map(
            .f = ~ tibble::tibble(
              file_name = purrr::chuck(.x, "file_name"),
              size = base::as.numeric(purrr::chuck(.x, "size")),
              sha256 = purrr::chuck(.x, "sha256")
            )
          ) |>
          purrr::list_rbind(ptype = data_files_empty)
      ),
      dev_files = purrr::map(
        .x = list_artefacts,
        .f = ~ purrr::pluck(.x, "dev", "files", .default = list()) |>
          base::unlist(use.names = FALSE) |>
          base::as.character()
      ),
      dev_directory = purrr::map2_chr(
        .x = list_artefacts,
        .y = list_contracts,
        .f = ~ purrr::pluck(
          .x, "dev", "directory",
          .default = purrr::chuck(.y, "producer", "directory")
        )
      )
    )

  return(res)
}
