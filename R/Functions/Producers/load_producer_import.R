#' @title Load a validated producer artefact for the import
#' @description
#' Read the resolved files of one producer artefact, or of one of its
#' variables, validate them against the artefact's contract, and cut them
#' to the subset box when the `subset` profile is active. This is the
#' command of each data target of the producer import stage.
#' @param data_files
#' A data frame as returned by `resolve_producer_artefact()` for the
#' artefact, with at least `artefact_id`, `file_name`, `path` and `format`.
#' @param path_contract
#' Character scalar. Path of the artefact's contract.
#' @param variable
#' Character scalar or `NULL` (default). For contracts with `variables`, the
#' variable whose files are read and validated. `NULL` reads every file and
#' is allowed only for contracts without variables.
#' @param list_subset
#' Named list. The `subset` section of `config.yml` (see
#' `filter_producer_artefact()`).
#' @param list_subset_filter
#' Named list. How the artefact is cut to the subset box (see
#' `filter_producer_artefact()`).
#' @param vec_keys_kept
#' Vector or `NULL` (default). The keys kept in the reference artefact of a
#' filter by key (see `filter_producer_artefact()`).
#' @return
#' Named list of data frames, one per file, named by file name in the order
#' of `data_files`: validated and, in the `subset` profile, filtered.
#' @details
#' The files of `variable` are selected with `filter_producer_files()`; a
#' variable without files aborts. Validation with
#' `validate_producer_artefact()` covers every file of the artefact (or
#' variable) before the subset filter, and aborts with an error of class
#' `producer_contract_error` that names the contract, the file, the column
#' and the rule.
#' @examples
#' \dontrun{
#' list_splot <-
#'   load_producer_import(
#'     data_files = data_files_splot_plots,
#'     path_contract = here::here("Data", "Contracts", "splot_plots.yml"),
#'     list_subset = load_config_value(value = "subset"),
#'     list_subset_filter = list(
#'       col_lon = "longitude",
#'       col_lat = "latitude",
#'       flag_margin = FALSE
#'     )
#'   )
#' }
load_producer_import <- function(
  data_files,
  path_contract,
  variable = NULL,
  list_subset,
  list_subset_filter,
  vec_keys_kept = NULL
) {
  validate_data_columns(
    data_source = data_files,
    vec_columns_required = c("artefact_id", "file_name", "path", "format"),
    name_argument = "data_files"
  )

  vec_artefact_ids <-
    dplyr::pull(data_files, artefact_id) |>
    base::unique()

  if (
    base::length(vec_artefact_ids) != 1L
  ) {
    cli::cli_abort(
      c(
        "`data_files` must hold the files of one artefact.",
        "x" = "It holds {base::length(vec_artefact_ids)} artefact{?s}."
      )
    )
  }

  contract <-
    load_producer_contract(path_contract = path_contract)

  contract_id <-
    purrr::chuck(contract, "contract_id")

  vec_variables_contract <-
    purrr::pluck(contract, "variables", "table", .default = list()) |>
    purrr::map_chr(.f = ~ purrr::chuck(.x, "variable"))

  #--------------------------------------------------#
  ## Files of the variable -----
  #--------------------------------------------------#

  if (
    base::is.null(variable) && base::length(vec_variables_contract) > 0L
  ) {
    cli::cli_abort(
      c(
        "The contract {.val {contract_id}} has variables; give one in
          {.arg variable}.",
        "i" = "Variables: {.val {vec_variables_contract}}."
      )
    )
  }

  # A selection that already holds one variable is kept as it is
  data_files_selected <-
    if (
      base::is.null(variable)
    ) {
      data_files
    } else {
      filter_producer_files(
        data_files = data_files,
        path_contract = path_contract,
        variable = variable
      )
    }

  #--------------------------------------------------#
  ## Read, validate and filter -----
  #--------------------------------------------------#

  list_artefact <-
    load_producer_artefact(
      data_files = data_files_selected,
      contract = contract
    )

  validate_producer_artefact(
    contract = contract,
    data_artefact = list_artefact,
    vec_variables = variable,
    verbose = FALSE
  )

  res <-
    filter_producer_artefact(
      list_artefact = list_artefact,
      list_subset = list_subset,
      list_subset_filter = list_subset_filter,
      vec_keys_kept = vec_keys_kept
    )

  return(res)
}
