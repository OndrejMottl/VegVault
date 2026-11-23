#' @title Load the variables of an abiotic producer contract
#' @description
#' Read the `variables` table of a climate contract and return, for each
#' variable, the name, unit and details that `prepare_abiotic_tables()`
#' stores in `AbioticVariable`.
#' @param path_contract
#' Character scalar. Path of a producer contract with a `variables` table,
#' for example `Data/Contracts/chelsa_neoclimate.yml`.
#' @return
#' A named list with one element per variable, in the order of the
#' contract and named by the variable, each a list of the text scalars
#' `name` (the contract `variable`), `unit` (its `unit`) and `details` (its
#' `description`).
#' @details
#' The contract is read with `load_producer_contract()`, which checks its
#' format. The validation stage compares `AbioticVariable` with the same
#' three fields of the contract, so they are taken from it unchanged.
#' Aborts when the contract has no `variables` table.
#' @seealso [prepare_abiotic_tables()], [load_producer_contract()]
#' @examples
#' \dontrun{
#' list_variables <-
#'   load_abiotic_variables(
#'     path_contract = here::here("Data", "Contracts", "chelsa_neoclimate.yml")
#'   )
#' }
load_abiotic_variables <- function(path_contract) {
  assertthat::assert_that(
    base::is.character(path_contract),
    base::length(path_contract) == 1L,
    !base::is.na(path_contract),
    base::nzchar(path_contract),
    msg = "`path_contract` must be a non-empty character scalar."
  )

  list_contract <-
    load_producer_contract(path_contract = path_contract)

  list_table <-
    purrr::pluck(list_contract, "variables", "table", .default = base::list())

  if (
    base::length(list_table) == 0L
  ) {
    cli::cli_abort(
      "The contract {.file {base::basename(path_contract)}} has no
      {.field variables} table."
    )
  }

  res <-
    list_table |>
    purrr::map(
      .f = ~ base::list(
        name = purrr::chuck(.x, "variable"),
        unit = purrr::chuck(.x, "unit"),
        details = purrr::chuck(.x, "description")
      )
    ) |>
    rlang::set_names(
      purrr::map_chr(.x = list_table, .f = ~ purrr::chuck(.x, "variable"))
    )

  return(res)
}
