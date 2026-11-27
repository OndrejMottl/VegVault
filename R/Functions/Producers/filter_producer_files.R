#' @title Filter the resolved files of a producer artefact to one variable
#' @description
#' Keep the resolved files of one variable of an artefact whose contract has
#' `variables` (one file, or one set of batches, per variable), so that
#' each variable is read, validated and rebuilt on its own.
#' @param data_files
#' A data frame as returned by `resolve_producer_artefact()`, with at least
#' the column `file_name`.
#' @param path_contract
#' Character scalar. Path of the artefact's contract.
#' @param variable
#' Character scalar. A variable of the contract's `variables`, such as
#' `"bio1"`.
#' @return
#' The rows of `data_files` whose file name encodes `variable`, with every
#' column and in the same order.
#' @details
#' The variable of each file comes from the contract's file-name templates
#' (`build_producer_file_table()`). Aborts when the contract has no
#' variables, when `variable` is not one of them, or when no file has it.
#' @examples
#' \dontrun{
#' filter_producer_files(
#'   data_files = data_files_chelsa_neoclimate,
#'   path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml"),
#'   variable = "bio1"
#' )
#' }
filter_producer_files <- function(
  data_files,
  path_contract,
  variable
) {
  validate_data_columns(
    data_source = data_files,
    vec_columns_required = "file_name",
    name_argument = "data_files"
  )

  assertthat::assert_that(
    base::is.character(variable),
    base::length(variable) == 1L,
    !base::is.na(variable),
    msg = "`variable` must be a character scalar."
  )

  contract <-
    load_producer_contract(path_contract = path_contract)

  contract_id <-
    purrr::chuck(contract, "contract_id")

  vec_variables_contract <-
    purrr::pluck(contract, "variables", "table", .default = list()) |>
    purrr::map_chr(.f = ~ purrr::chuck(.x, "variable"))

  if (
    base::length(vec_variables_contract) == 0L
  ) {
    cli::cli_abort(
      "The contract {.val {contract_id}} has no variables to select."
    )
  }

  if (
    !variable %in% vec_variables_contract
  ) {
    cli::cli_abort(
      c(
        "{.val {variable}} is not a variable of the contract
          {.val {contract_id}}.",
        "i" = "Variables: {.val {vec_variables_contract}}."
      )
    )
  }

  vec_file_variables <-
    build_producer_file_table(
      vec_file_names = dplyr::pull(data_files, file_name),
      contract = contract
    ) |>
    dplyr::pull(var = "variable")

  res <-
    dplyr::filter(data_files, vec_file_variables %in% !!variable)

  if (
    base::nrow(res) == 0L
  ) {
    cli::cli_abort(
      "The resolved files of {.val {contract_id}} have no file of the
        variable {.val {variable}}."
    )
  }

  return(res)
}
