#' @title Select the files of a producer's contract copy
#' @description
#' List the files that a producer copies from a VegVault checkout: every
#' function file of `R/Functions/Contracts/` (the validator and its
#' helpers) and the producer's own contracts in `Data/Contracts/`, each
#' with its fingerprint.
#' @param path_vegvault
#' Character scalar. Root folder of a VegVault checkout.
#' @param repository
#' Character scalar. The producer repository as the contracts name it in
#' `producer: repository`, for example
#' `"OndrejMottl/VegVault-Vegetation_data"`.
#' @return
#' A tibble with one row per file, sorted by `path`: `path` (character,
#' relative to the checkout root, with `/` as separator), `sha256`
#' (character, from `compute_text_file_sha256()`), `contract_id` and
#' `contract_version` (character; `NA` for function files).
#' @details
#' A contract belongs to the producer when its `producer: repository`
#' equals `repository` and its `status` is not `"retired"`. Only `.R`
#' files directly in `R/Functions/Contracts/` and `.yml` files directly in
#' `Data/Contracts/` are considered, so fixtures and `README.md` are never
#' part of a copy. The contracts are read as plain YAML rather than with
#' `load_producer_contract()`, so that an older copy of these functions can
#' still compare itself with a newer VegVault checkout. Aborts when the
#' checkout has no contract function, when a `.yml` file lacks
#' `contract_id`, `contract_version`, `status` or `producer: repository`,
#' or when no contract belongs to `repository`.
#' @seealso [save_contract_copy()], [validate_contract_copy()]
#' @examples
#' \dontrun{
#' select_contract_copy_files(
#'   path_vegvault = here::here(),
#'   repository = "OndrejMottl/VegVault-Vegetation_data"
#' )
#' }
select_contract_copy_files <- function(
  path_vegvault,
  repository
) {
  assertthat::assert_that(
    base::is.character(path_vegvault),
    base::length(path_vegvault) == 1L,
    !base::is.na(path_vegvault),
    base::dir.exists(path_vegvault),
    msg = "`path_vegvault` must be the path of an existing folder."
  )

  assertthat::assert_that(
    base::is.character(repository),
    base::length(repository) == 1L,
    !base::is.na(repository),
    base::nzchar(repository),
    msg = "`repository` must be a non-empty character scalar."
  )

  #--------------------------------------------------#
  ## Contract functions -----
  #--------------------------------------------------#

  vec_function_files <-
    base::list.files(
      path = base::file.path(path_vegvault, "R", "Functions", "Contracts"),
      pattern = "[.]R$"
    )

  if (
    base::length(vec_function_files) == 0L
  ) {
    cli::cli_abort(
      c(
        "The VegVault checkout has no contract functions.",
        "i" = "Expected {.file .R} files in {.path R/Functions/Contracts}
        of {.path {path_vegvault}}."
      )
    )
  }

  #--------------------------------------------------#
  ## Contracts of the producer -----
  #--------------------------------------------------#

  vec_contract_files <-
    base::list.files(
      path = base::file.path(path_vegvault, "Data", "Contracts"),
      pattern = "[.]yml$"
    )

  list_contracts_raw <-
    purrr::map(
      .x = vec_contract_files,
      .f = ~ yaml::read_yaml(
        file = base::file.path(path_vegvault, "Data", "Contracts", .x)
      )
    )

  # A field counts only when it holds one non-missing text value; a
  #   character index plucks nested fields and gives NULL when absent
  data_contracts <-
    tibble::tibble(
      file_name = vec_contract_files,
      contract_id = purrr::map(list_contracts_raw, "contract_id"),
      contract_version = purrr::map(list_contracts_raw, "contract_version"),
      status = purrr::map(list_contracts_raw, "status"),
      repository = purrr::map(
        list_contracts_raw,
        c("producer", "repository")
      )
    ) |>
    dplyr::mutate(
      dplyr::across(
        .cols = c("contract_id", "contract_version", "status", "repository"),
        .fns = ~ purrr::map_chr(
          .x = .x,
          .f = ~ if (rlang::is_string(.x)) .x else NA_character_
        )
      )
    )

  vec_files_incomplete <-
    data_contracts |>
    dplyr::filter(
      base::is.na(contract_id) |
        base::is.na(contract_version) |
        base::is.na(status) |
        base::is.na(repository)
    ) |>
    dplyr::pull(file_name)

  if (
    base::length(vec_files_incomplete) > 0L
  ) {
    cli::cli_abort(
      c(
        "Contract files in {.path {path_vegvault}} lack contract_id,
        contract_version, status or producer: repository.",
        "x" = "{.file {vec_files_incomplete}}"
      )
    )
  }

  data_contracts_selected <-
    data_contracts |>
    dplyr::filter(
      .data$repository == .env$repository,
      .data$status != "retired"
    )

  if (
    base::nrow(data_contracts_selected) == 0L
  ) {
    cli::cli_abort(
      c(
        "No contract in {.path {path_vegvault}} belongs to
        {.val {repository}}.",
        "i" = "A contract belongs to a producer when its
        {.field producer: repository} names it and it is not retired."
      )
    )
  }

  #--------------------------------------------------#
  ## Table of files -----
  #--------------------------------------------------#

  data_files_selected <-
    dplyr::bind_rows(
      tibble::tibble(
        path = stringr::str_c("R/Functions/Contracts/", vec_function_files),
        contract_id = NA_character_,
        contract_version = NA_character_
      ),
      data_contracts_selected |>
        dplyr::transmute(
          path = stringr::str_c("Data/Contracts/", file_name),
          contract_id,
          contract_version
        )
    )

  res <-
    data_files_selected |>
    dplyr::mutate(
      sha256 = purrr::map_chr(
        .x = path,
        .f = ~ compute_text_file_sha256(
          path_file = base::file.path(path_vegvault, .x)
        )
      ),
      .after = path
    ) |>
    dplyr::arrange(path)

  return(res)
}
