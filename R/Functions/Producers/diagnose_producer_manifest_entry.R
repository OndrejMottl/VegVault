#' @title Diagnose one artefact entry of the producer pin manifest
#' @description
#' Check one entry of `artefacts` in the producer pin manifest against the
#' manifest format and against the contract of the artefact, and list
#' every problem.
#' @param list_entry
#' A named list: one element of `artefacts` as read from the YAML file.
#' @param dir_contracts
#' Character scalar. The folder of the contracts (`Data/Contracts`).
#' @return
#' A character vector with one problem per element, each starting with the
#' artefact id (or `artefact` when the id is unusable); empty when the
#' entry is valid.
#' @details
#' The entry needs `artefact_id`, `contract_version`, `release` and `dev`
#' and may have a `note`; other fields are problems. The contract
#' `<dir_contracts>/<artefact_id>.yml` must exist and have the same
#' `contract_version`. `release` has `tag` and `files`: a placeholder has
#' no tag (`null`) and no files; a pinned entry has a release tag (see
#' `is_release_tag()`) and at least one file, each with `file_name`,
#' `size` (bytes, a positive whole number) and `sha256` (64 lower-case
#' hexadecimal characters). `dev` has `files`, a possibly empty list of
#' file names, and may have `directory`, the folder of those files relative
#' to the producer checkout (for example `Outputs/Data_temp`, where a
#' producer built from the project template writes its test artefacts),
#' with forward slashes and no empty, `.` or `..` part; without it, the dev
#' files are in the contract's folder. Every file name must be a plain name
#' that matches a
#' file-name template of the contract, and no name may repeat within
#' `release` or within `dev`.
#' @examples
#' \dontrun{
#' diagnose_producer_manifest_entry(
#'   list_entry = list_manifest_entry,
#'   dir_contracts = here::here("Data", "Contracts")
#' )
#' }
diagnose_producer_manifest_entry <- function(
  list_entry,
  dir_contracts
) {
  assertthat::assert_that(
    base::is.list(list_entry),
    msg = "`list_entry` must be a list."
  )

  assertthat::assert_that(
    base::is.character(dir_contracts),
    base::length(dir_contracts) == 1L,
    base::dir.exists(dir_contracts),
    msg = "`dir_contracts` must be an existing folder."
  )

  vec_fields <-
    base::as.character(base::names(list_entry))

  artefact_id <-
    purrr::pluck(list_entry, "artefact_id")

  flag_id_valid <-
    base::is.character(artefact_id) &&
    base::length(artefact_id) == 1L &&
    !base::is.na(artefact_id) &&
    base::nzchar(artefact_id)

  label_entry <-
    if (
      flag_id_valid
    ) {
      artefact_id
    } else {
      "artefact"
    }

  path_contract <-
    if (
      flag_id_valid
    ) {
      base::file.path(dir_contracts, stringr::str_c(artefact_id, ".yml"))
    } else {
      NA_character_
    }

  contract <-
    if (
      flag_id_valid && base::file.exists(path_contract)
    ) {
      load_producer_contract(path_contract = path_contract)
    } else {
      NULL
    }

  value_version <-
    purrr::pluck(list_entry, "contract_version")

  value_note <-
    purrr::pluck(list_entry, "note")

  #--------------------------------------------------#
  ## Fields, contract and version -----
  #--------------------------------------------------#

  vec_problems_top <-
    c(
      stringr::str_c(
        "missing field '",
        base::setdiff(
          c("artefact_id", "contract_version", "release", "dev"),
          vec_fields
        ),
        "'."
      ),
      stringr::str_c(
        "unknown field '",
        base::setdiff(
          vec_fields,
          c("artefact_id", "contract_version", "note", "release", "dev")
        ),
        "'."
      ),
      if (
        "artefact_id" %in% vec_fields && !flag_id_valid
      ) {
        "artefact_id: must be a non-empty text value."
      },
      if (
        flag_id_valid && base::is.null(contract)
      ) {
        stringr::str_c(
          "there is no contract '", artefact_id, ".yml' in the contract ",
          "folder."
        )
      },
      if (
        !base::is.null(contract) &&
          "contract_version" %in% vec_fields &&
          !base::identical(
            base::as.character(value_version),
            purrr::chuck(contract, "contract_version")
          )
      ) {
        stringr::str_c(
          "contract_version '", base::as.character(value_version),
          "' differs from the contract (",
          purrr::chuck(contract, "contract_version"), ")."
        )
      },
      if (
        !base::is.null(value_note) &&
          !(base::is.character(value_note) && base::length(value_note) == 1L)
      ) {
        "note: must be one text value."
      }
    )

  vec_release_fields <-
    base::as.character(base::names(purrr::pluck(list_entry, "release")))

  list_release <-
    purrr::pluck(list_entry, "release", .default = list())

  value_tag <-
    purrr::pluck(list_release, "tag")

  value_release_files <-
    purrr::pluck(list_release, "files", .default = list())

  # `files` must be a YAML sequence (an unnamed list); anything else is
  #   reported once and not checked further
  flag_release_files_list <-
    base::is.list(value_release_files) &&
    base::is.null(base::names(value_release_files))

  list_release_files <-
    if (
      flag_release_files_list
    ) {
      value_release_files
    } else {
      list()
    }

  # The name of each file entry, or NA when it is not one text value
  vec_release_names <-
    purrr::map_chr(
      .x = list_release_files,
      .f = ~ {
        value_name <-
          purrr::pluck(.x, "file_name")

        if (
          base::is.list(.x) &&
            base::is.character(value_name) &&
            base::length(value_name) == 1L &&
            !base::is.na(value_name)
        ) {
          value_name
        } else {
          NA_character_
        }
      }
    )

  #--------------------------------------------------#
  ## Release entry -----
  #--------------------------------------------------#

  vec_problems_release_files <-
    purrr::imap(
      .x = list_release_files,
      .f = ~ {
        path_file <-
          stringr::str_c("release.files[", .y, "]")

        flag_map <-
          base::is.list(.x) && !base::is.null(base::names(.x))

        vec_file_fields <-
          base::as.character(base::names(.x))

        value_name <-
          purrr::pluck(.x, "file_name")

        value_size <-
          purrr::pluck(.x, "size")

        value_sha <-
          purrr::pluck(.x, "sha256")

        if (
          !flag_map
        ) {
          stringr::str_c(
            path_file, ": must be a map with file_name, size and sha256."
          )
        } else {
          c(
            if (
              "file_name" %in% vec_file_fields &&
                !(
                  base::is.character(value_name) &&
                    base::length(value_name) == 1L &&
                    !base::is.na(value_name)
                )
            ) {
              stringr::str_c(path_file, ": file_name must be one text value.")
            },
            stringr::str_c(
              path_file, ": missing field '",
              base::setdiff(c("file_name", "size", "sha256"), vec_file_fields),
              "'."
            ),
            stringr::str_c(
              path_file, ": unknown field '",
              base::setdiff(vec_file_fields, c("file_name", "size", "sha256")),
              "'."
            ),
            if (
              "size" %in% vec_file_fields &&
                !(
                  is_positive_number(value_size) &&
                    value_size == base::round(value_size)
                )
            ) {
              stringr::str_c(
                path_file,
                ": size must be a positive whole number."
              )
            },
            if (
              "sha256" %in% vec_file_fields &&
                !(
                  base::is.character(value_sha) &&
                    base::length(value_sha) == 1L &&
                    stringr::str_detect(value_sha, "^[0-9a-f]{64}$") %in% TRUE
                )
            ) {
              stringr::str_c(
                path_file,
                ": sha256 must be 64 lower-case hexadecimal characters."
              )
            }
          )
        }
      }
    ) |>
    base::unlist(use.names = FALSE)

  vec_problems_release <-
    if (
      "release" %in% vec_fields
    ) {
      c(
        stringr::str_c(
          "release: missing field '",
          base::setdiff(c("tag", "files"), vec_release_fields),
          "'."
        ),
        stringr::str_c(
          "release: unknown field '",
          base::setdiff(vec_release_fields, c("tag", "files")),
          "'."
        ),
        if (
          !flag_release_files_list
        ) {
          "release.files: must be a list of files."
        },
        if (
          !base::is.null(value_tag) && !is_release_tag(value_tag)
        ) {
          stringr::str_c(
            "release.tag '",
            stringr::str_flatten(base::as.character(value_tag), collapse = " "),
            "' is not a release tag such as v2.0.0."
          )
        },
        if (
          base::is.null(value_tag) && base::length(list_release_files) > 0L
        ) {
          "release: a placeholder (tag null) must not list files."
        },
        if (
          !base::is.null(value_tag) && base::length(list_release_files) == 0L
        ) {
          "release: a tagged entry has no files."
        },
        vec_problems_release_files
      )
    }

  #--------------------------------------------------#
  ## Dev entry -----
  #--------------------------------------------------#

  vec_dev_fields <-
    base::as.character(base::names(purrr::pluck(list_entry, "dev")))

  value_dev_files <-
    purrr::pluck(list_entry, "dev", "files", .default = list())

  # A YAML sequence of names: a character vector, or an unnamed list of
  #   single names (nested lists and maps are not file lists)
  flag_dev_files_valid <-
    base::is.null(base::names(value_dev_files)) &&
    (
      base::is.character(value_dev_files) ||
        (
          base::is.list(value_dev_files) &&
            base::all(
              purrr::map_lgl(
                .x = value_dev_files,
                .f = ~ base::is.character(.x) && base::length(.x) == 1L
              )
            )
        )
    )

  vec_dev_names <-
    if (
      flag_dev_files_valid
    ) {
      value_dev_files |>
        base::unlist(use.names = FALSE) |>
        base::as.character()
    } else {
      base::character(0)
    }

  # An optional folder of the dev files, relative to the producer checkout:
  #   forward slashes, no empty, `.` or `..` part, no drive or root
  value_dev_directory <-
    purrr::pluck(list_entry, "dev", "directory")

  vec_directory_parts <-
    if (
      assertthat::is.string(value_dev_directory)
    ) {
      stringr::str_split_1(value_dev_directory, pattern = "/")
    } else {
      base::character(0)
    }

  flag_dev_directory_valid <-
    base::is.null(value_dev_directory) ||
    (
      assertthat::is.string(value_dev_directory) &&
        !base::is.na(value_dev_directory) &&
        !stringr::str_detect(value_dev_directory, "[\\\\:]") &&
        base::all(base::nzchar(vec_directory_parts)) &&
        !base::any(vec_directory_parts %in% c(".", ".."))
    )

  vec_problems_dev <-
    if (
      "dev" %in% vec_fields
    ) {
      c(
        stringr::str_c(
          "dev: missing field '",
          base::setdiff("files", vec_dev_fields),
          "'."
        ),
        stringr::str_c(
          "dev: unknown field '",
          base::setdiff(vec_dev_fields, c("files", "directory")),
          "'."
        ),
        if (
          !flag_dev_files_valid
        ) {
          "dev.files: must be a list of file names."
        },
        if (
          !flag_dev_directory_valid
        ) {
          stringr::str_c(
            "dev.directory: must be a relative folder inside the producer ",
            "checkout, with forward slashes, such as 'Outputs/Data_temp'."
          )
        }
      )
    }

  #--------------------------------------------------#
  ## File names -----
  #--------------------------------------------------#

  list_names <-
    list(
      "release.files" = vec_release_names,
      "dev.files" = vec_dev_names
    )

  vec_problems_names <-
    purrr::imap(
      .x = list_names,
      .f = ~ {
        # Missing names are reported by the field checks above
        vec_names <-
          .x[!base::is.na(.x)]

        field_name <- .y

        vec_names_plain <-
          vec_names[!stringr::str_detect(vec_names, "[/\\\\]")]

        # Only plain names go to the template check, which refuses paths
        vec_names_unmatched <-
          if (
            !base::is.null(contract) && base::length(vec_names_plain) > 0L
          ) {
            vec_names_plain[
              !dplyr::pull(
                build_producer_file_table(
                  vec_file_names = vec_names_plain,
                  contract = contract
                ),
                "is_match"
              )
            ]
          } else {
            base::character(0)
          }

        vec_duplicated <-
          vec_names[base::duplicated(vec_names)] |>
          base::unique()

        c(
          stringr::str_c(
            field_name, ": '", base::setdiff(vec_names, vec_names_plain),
            "' must be a plain file name."
          ),
          stringr::str_c(
            field_name, ": '", vec_names_unmatched,
            "' does not match a file-name template of the contract."
          ),
          stringr::str_c(
            field_name, ": '", vec_duplicated, "' is listed more than once."
          )
        )
      }
    ) |>
    base::unlist(use.names = FALSE)

  vec_problems <-
    c(
      base::character(0),
      vec_problems_top,
      vec_problems_release,
      vec_problems_dev,
      vec_problems_names
    )

  res <-
    if (
      base::length(vec_problems) > 0L
    ) {
      stringr::str_c(label_entry, ": ", vec_problems)
    } else {
      base::character(0)
    }

  return(res)
}
