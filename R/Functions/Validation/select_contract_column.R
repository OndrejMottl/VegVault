#' @title Select one column of a producer contract
#' @description
#' Return the specification of one named column of a loaded producer
#' contract: its class, unit, description and checks.
#' @param contract
#' A producer contract, as returned by `load_producer_contract()`.
#' @param column
#' Character scalar. The name of the column.
#' @return
#' The named list of the column, as in the contract; `checks` is an empty
#' list when the contract lists none.
#' @details
#' Aborts when the contract has no column of that name or more than one.
#' @examples
#' \dontrun{
#' select_contract_column(
#'   contract = load_producer_contract(
#'     path_contract = here::here("Data", "Contracts", "hwsd_soil.yml")
#'   ),
#'   column = "value"
#' )
#' }
select_contract_column <- function(
  contract,
  column
) {
  assertthat::assert_that(
    base::is.list(contract),
    base::is.list(purrr::pluck(contract, "columns")),
    msg = "'contract' must be a contract with a list of columns."
  )

  assertthat::assert_that(
    assertthat::is.string(column),
    msg = "'column' must be a character scalar."
  )

  list_found <-
    purrr::keep(
      .x = purrr::chuck(contract, "columns"),
      .p = ~ base::identical(purrr::pluck(.x, "name"), column)
    )

  if (
    base::length(list_found) != 1L
  ) {
    cli::cli_abort(
      "The contract {.val {purrr::pluck(contract, 'contract_id')}} must have
      one column {.field {column}}, not {base::length(list_found)}."
    )
  }

  res <-
    purrr::pluck(list_found, 1L)

  res[["checks"]] <-
    purrr::pluck(res, "checks", .default = base::list())

  return(res)
}
