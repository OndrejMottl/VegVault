#' @title Load the record of a producer's contract copy
#' @description
#' Read `Data/Contracts/contract_copy.yml` in a producer checkout, the
#' record that `save_contract_copy()` writes next to the copied contracts,
#' and check its structure.
#' @param path_producer
#' Character scalar. Root folder of the producer checkout.
#' @return
#' A list with `vegvault_commit` (character scalar, the 40-character
#' VegVault commit the copy was taken from), `producer_repository`
#' (character scalar) and `data_files`, a tibble with the columns of
#' `select_contract_copy_files()` (`path`, `sha256`, `contract_id`,
#' `contract_version`), sorted by `path`.
#' @details
#' The record has exactly the fields `vegvault_commit`,
#' `producer_repository` and `files`; each entry of `files` has `path` and
#' `sha256`, and an entry for a contract (a `.yml` path) also has
#' `contract_id`, equal to the file name without `.yml`, and
#' `contract_version`. Every path must be a `.R` file directly in
#' `R/Functions/Contracts/` or a `.yml` file directly in `Data/Contracts/`,
#' because `save_contract_copy()` deletes the listed files when it replaces
#' a copy; a path must not occur twice. Aborts with every problem found
#' when the record is missing or breaks these rules.
#' @seealso [save_contract_copy()], [validate_contract_copy()]
#' @examples
#' \dontrun{
#' load_contract_copy_record(path_producer = here::here())
#' }
load_contract_copy_record <- function(path_producer) {
  assertthat::assert_that(
    base::is.character(path_producer),
    base::length(path_producer) == 1L,
    !base::is.na(path_producer),
    base::dir.exists(path_producer),
    msg = "`path_producer` must be the path of an existing folder."
  )

  path_record <-
    base::file.path(path_producer, "Data", "Contracts", "contract_copy.yml")

  if (
    !base::file.exists(path_record)
  ) {
    cli::cli_abort(
      c(
        "{.path {path_producer}} has no contract copy record.",
        "i" = "Expected {.file Data/Contracts/contract_copy.yml}, written by
        {.fn save_contract_copy}."
      )
    )
  }

  list_record <-
    base::tryCatch(
      yaml::read_yaml(file = path_record),
      error = function(error) {
        cli::cli_abort(
          "{.file Data/Contracts/contract_copy.yml} is not valid YAML.",
          parent = error
        )
      }
    )

  if (
    !base::is.list(list_record) || base::is.null(base::names(list_record))
  ) {
    cli::cli_abort(
      "{.file Data/Contracts/contract_copy.yml} must be a YAML map with the
      fields vegvault_commit, producer_repository and files."
    )
  }

  #--------------------------------------------------#
  ## Top-level fields -----
  #--------------------------------------------------#

  vec_fields_required <-
    c("vegvault_commit", "producer_repository", "files")

  vec_fields <-
    base::names(list_record)

  value_commit <-
    purrr::pluck(list_record, "vegvault_commit")

  value_repository <-
    purrr::pluck(list_record, "producer_repository")

  list_files_raw <-
    purrr::pluck(list_record, "files")

  vec_problems_top <-
    c(
      stringr::str_c(
        "missing field ",
        base::setdiff(vec_fields_required, vec_fields),
        "."
      ),
      stringr::str_c(
        "unknown field ",
        base::setdiff(vec_fields, vec_fields_required),
        "."
      ),
      if (
        "vegvault_commit" %in% vec_fields &&
          !(
            rlang::is_string(value_commit) &&
              stringr::str_detect(value_commit, "^[0-9a-f]{40}$")
          )
      ) {
        "vegvault_commit must be a 40-character lower-case commit hash."
      },
      if (
        "producer_repository" %in% vec_fields &&
          !(
            rlang::is_string(value_repository) &&
              base::nzchar(value_repository)
          )
      ) {
        "producer_repository must be one non-empty text value."
      },
      if (
        "files" %in% vec_fields &&
          !(base::is.list(list_files_raw) && base::length(list_files_raw) > 0L)
      ) {
        "files must list at least one copied file."
      }
    )

  #--------------------------------------------------#
  ## File entries -----
  #--------------------------------------------------#

  # Text values only; anything else counts as missing
  list_files_valid <-
    if (
      base::is.list(list_files_raw)
    ) {
      list_files_raw
    } else {
      base::list()
    }

  data_files_raw <-
    tibble::tibble(
      path = purrr::map(list_files_valid, "path"),
      sha256 = purrr::map(list_files_valid, "sha256"),
      contract_id = purrr::map(list_files_valid, "contract_id"),
      contract_version = purrr::map(list_files_valid, "contract_version")
    ) |>
    dplyr::mutate(
      dplyr::across(
        .cols = c("path", "sha256", "contract_id", "contract_version"),
        .fns = ~ purrr::map_chr(
          .x = .x,
          .f = ~ if (rlang::is_string(.x)) .x else NA_character_
        )
      )
    ) |>
    dplyr::mutate(
      label = dplyr::if_else(
        base::is.na(path),
        stringr::str_c("files entry ", dplyr::row_number()),
        path
      ),
      is_function = stringr::str_detect(
        dplyr::coalesce(path, ""),
        "^R/Functions/Contracts/[^/]+[.]R$"
      ),
      is_contract = stringr::str_detect(
        dplyr::coalesce(path, ""),
        "^Data/Contracts/[^/]+[.]yml$"
      ) &
        dplyr::coalesce(path, "") != "Data/Contracts/contract_copy.yml",
      id_expected = stringr::str_remove(
        base::basename(dplyr::coalesce(path, "")),
        "[.]yml$"
      ),
      is_duplicated = !base::is.na(path) &
        (base::duplicated(path) | base::duplicated(path, fromLast = TRUE))
    )

  vec_problems_files <-
    c(
      data_files_raw |>
        dplyr::filter(base::is.na(path)) |>
        dplyr::pull(label) |>
        stringr::str_c(": path must be one text value."),
      data_files_raw |>
        dplyr::filter(
          !base::is.na(path),
          !is_function,
          !is_contract
        ) |>
        dplyr::pull(label) |>
        stringr::str_c(
          ": path must be a .R file directly in R/Functions/Contracts or ",
          "a .yml file directly in Data/Contracts."
        ),
      data_files_raw |>
        dplyr::filter(
          base::is.na(sha256) |
            !stringr::str_detect(dplyr::coalesce(sha256, ""), "^[0-9a-f]{64}$")
        ) |>
        dplyr::pull(label) |>
        stringr::str_c(
          ": sha256 must be 64 lower-case hexadecimal characters."
        ),
      data_files_raw |>
        dplyr::filter(
          is_contract,
          base::is.na(contract_id) | contract_id != id_expected
        ) |>
        dplyr::pull(label) |>
        stringr::str_c(": contract_id must equal the file name without .yml."),
      data_files_raw |>
        dplyr::filter(
          is_contract,
          !stringr::str_detect(
            dplyr::coalesce(contract_version, ""),
            "^[0-9]+[.][0-9]+[.][0-9]+$"
          )
        ) |>
        dplyr::pull(label) |>
        stringr::str_c(
          ": contract_version must be a version such as 1.0.0."
        ),
      data_files_raw |>
        dplyr::filter(is_duplicated) |>
        dplyr::distinct(label) |>
        dplyr::pull(label) |>
        stringr::str_c(": listed twice.")
    )

  vec_problems <-
    c(vec_problems_top, vec_problems_files)

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
        "The contract copy record {.file Data/Contracts/contract_copy.yml}
        in {.path {path_producer}} is not valid.",
        vec_problems_escaped,
        "i" = "Make the copy again with {.fn save_contract_copy}."
      )
    )
  }

  #--------------------------------------------------#
  ## Result -----
  #--------------------------------------------------#

  data_files <-
    data_files_raw |>
    dplyr::select("path", "sha256", "contract_id", "contract_version") |>
    dplyr::arrange(path)

  res <-
    base::list(
      vegvault_commit = value_commit,
      producer_repository = value_repository,
      data_files = data_files
    )

  return(res)
}
