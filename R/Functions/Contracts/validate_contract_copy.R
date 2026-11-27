#' @title Validate a producer's copy of the VegVault contracts
#' @description
#' Check that the contract files in a producer checkout are exactly the
#' files `save_contract_copy()` wrote, and, when a VegVault checkout is
#' given and present, that they are still the files VegVault would copy
#' now. Producers call it in their tests, so that a hand-edited or
#' outdated copy fails before an export is validated and tagged.
#' @param path_producer
#' Character scalar. Root folder of the producer checkout.
#' @param path_vegvault
#' Character scalar or `NULL` (default). Root folder of a VegVault checkout
#' to compare with. When `NULL`, or when the folder does not exist, the
#' comparison is skipped and only the copy itself is checked.
#' @param verbose
#' Logical. If `TRUE` (default), a summary is printed to the console via
#' `cli`, including when the comparison with VegVault is skipped.
#' @return
#' Invisibly, the `data_files` table of the record (see
#' `load_contract_copy_record()`).
#' @details
#' Always checked: the record `Data/Contracts/contract_copy.yml` loads;
#' every file it lists exists and has the recorded fingerprint; and
#' `R/Functions/Contracts/` holds no other `.R` file and `Data/Contracts/`
#' no other `.yml` file than those listed and the record. Checked against
#' `path_vegvault`: the listed files equal, path by path and fingerprint by
#' fingerprint, what `select_contract_copy_files()` selects in that
#' checkout for the record's producer repository. The comparison uses the
#' files as they are in that checkout, whatever branch it is on.
#' Fingerprints ignore line endings (`compute_text_file_sha256()`). Aborts
#' with every problem found, each naming its file, with an error of class
#' `contract_copy_error`.
#' @seealso [save_contract_copy()], [load_contract_copy_record()]
#' @examples
#' \dontrun{
#' validate_contract_copy(
#'   path_producer = here::here(),
#'   path_vegvault = here::here("..", "VegVault")
#' )
#' }
validate_contract_copy <- function(
  path_producer,
  path_vegvault = NULL,
  verbose = TRUE
) {
  assertthat::assert_that(
    base::is.character(path_producer),
    base::length(path_producer) == 1L,
    !base::is.na(path_producer),
    base::dir.exists(path_producer),
    msg = "`path_producer` must be the path of an existing folder."
  )

  assertthat::assert_that(
    base::is.null(path_vegvault) ||
      (
        base::is.character(path_vegvault) &&
          base::length(path_vegvault) == 1L &&
          !base::is.na(path_vegvault)
      ),
    msg = "`path_vegvault` must be NULL or a character scalar."
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  list_record <-
    load_contract_copy_record(path_producer = path_producer)

  data_files_record <-
    purrr::chuck(list_record, "data_files")

  #--------------------------------------------------#
  ## The copy against its record -----
  #--------------------------------------------------#

  data_files_checked <-
    data_files_record |>
    dplyr::mutate(
      is_present = base::file.exists(base::file.path(path_producer, path)),
      sha256_now = purrr::map2_chr(
        .x = path,
        .y = is_present,
        .f = ~ if (.y) {
          compute_text_file_sha256(
            path_file = base::file.path(path_producer, .x)
          )
        } else {
          NA_character_
        }
      )
    )

  vec_paths_existing <-
    c(
      stringr::str_c(
        "R/Functions/Contracts/",
        base::list.files(
          path = base::file.path(path_producer, "R", "Functions", "Contracts"),
          pattern = "[.]R$"
        )
      ),
      stringr::str_c(
        "Data/Contracts/",
        base::list.files(
          path = base::file.path(path_producer, "Data", "Contracts"),
          pattern = "[.]yml$"
        )
      )
    ) |>
    base::setdiff("Data/Contracts/contract_copy.yml")

  vec_problems_copy <-
    c(
      data_files_checked |>
        dplyr::filter(!is_present) |>
        dplyr::pull(path) |>
        stringr::str_c(": listed in the record but missing."),
      data_files_checked |>
        dplyr::filter(is_present, sha256_now != sha256) |>
        dplyr::pull(path) |>
        stringr::str_c(": changed since it was copied."),
      base::setdiff(vec_paths_existing, dplyr::pull(data_files_record, path)) |>
        stringr::str_c(": not part of the copy.")
    )

  #--------------------------------------------------#
  ## The copy against VegVault -----
  #--------------------------------------------------#

  flag_compare <-
    !base::is.null(path_vegvault) && base::dir.exists(path_vegvault)

  vec_problems_vegvault <-
    if (
      flag_compare
    ) {
      data_files_vegvault <-
        select_contract_copy_files(
          path_vegvault = path_vegvault,
          repository = purrr::chuck(list_record, "producer_repository")
        )

      data_compared <-
        dplyr::full_join(
          x = data_files_record,
          y = data_files_vegvault,
          by = dplyr::join_by(path),
          suffix = c("_copy", "_vegvault")
        )

      c(
        data_compared |>
          dplyr::filter(base::is.na(sha256_vegvault)) |>
          dplyr::pull(path) |>
          stringr::str_c(": no longer in the VegVault checkout."),
        data_compared |>
          dplyr::filter(base::is.na(sha256_copy)) |>
          dplyr::pull(path) |>
          stringr::str_c(": in the VegVault checkout but not in the copy."),
        data_compared |>
          dplyr::filter(
            !base::is.na(sha256_copy),
            !base::is.na(sha256_vegvault),
            sha256_copy != sha256_vegvault
          ) |>
          dplyr::mutate(
            text_versions = dplyr::if_else(
              base::is.na(contract_version_copy),
              "",
              stringr::str_c(
                " (copy ", contract_version_copy,
                ", VegVault ", contract_version_vegvault, ")"
              )
            ),
            text_problem = stringr::str_c(
              path,
              ": differs from the VegVault checkout",
              text_versions,
              "."
            )
          ) |>
          dplyr::pull(text_problem)
      )
    } else {
      base::character(0)
    }

  vec_problems <-
    c(vec_problems_copy, vec_problems_vegvault)

  if (
    base::length(vec_problems) > 0L
  ) {
    # Paths may hold braces, which cli would read as glue expressions
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
        "The VegVault contract copy in {.path {path_producer}} is not
        valid.",
        vec_problems_escaped,
        "i" = "Make the copy again with {.fn save_contract_copy} from a
        VegVault checkout on the shared branch, then commit it (see
        {.file Data/Contracts/README.md} in VegVault)."
      ),
      class = "contract_copy_error"
    )
  }

  if (
    base::isTRUE(verbose)
  ) {
    n_files <-
      base::nrow(data_files_record)

    commit_short <-
      list_record |>
      purrr::chuck("vegvault_commit") |>
      stringr::str_sub(1L, 7L)

    cli::cli_inform(
      c(
        "v" = "The contract copy matches its record: {n_files} files from
        VegVault commit {commit_short}.",
        if (
          flag_compare
        ) {
          c("v" = "It also matches the VegVault checkout at
            {.path {path_vegvault}}.")
        } else {
          c("i" = "The comparison with a VegVault checkout was skipped.")
        }
      )
    )
  }

  return(invisible(data_files_record))
}
