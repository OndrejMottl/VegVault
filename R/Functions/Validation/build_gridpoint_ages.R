#' @title Build the ages of the gridpoints from the palaeoclimate contract
#' @description
#' Convert the CHELSA-TraCE21k time slices that the palaeoclimate contract
#' allows into the ages, in years before 1950, at which gridpoints exist.
#' @param path_contract
#' Character scalar. Path of the `chelsa_trace21k_palaeoclimate` contract.
#' Default: the contract in `Data/Contracts/`.
#' @return
#' Numeric vector of the distinct ages, sorted in increasing order (0 to
#' 18000 in steps of 500 for contract 2.0.0).
#' @details
#' Reads `allowed_values` of the column `time_id` and converts them with
#' `prepare_chelsa_trace21k_ages()`, as the gridpoint stage does with the
#' time slices of the artefact. Aborts when the contract has no `time_id`
#' column or the column lists no allowed values.
#' @examples
#' \dontrun{
#' build_gridpoint_ages()
#' }
build_gridpoint_ages <- function(
  path_contract = here::here(
    "Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml"
  )
) {
  contract <-
    load_producer_contract(path_contract = path_contract)

  vec_time_ids <-
    select_contract_column(contract = contract, column = "time_id") |>
    purrr::pluck("checks", "allowed_values")

  if (
    base::length(vec_time_ids) == 0L
  ) {
    cli::cli_abort(
      "The contract {.file {path_contract}} lists no allowed values of
      {.field time_id}."
    )
  }

  res <-
    prepare_chelsa_trace21k_ages(
      list_data = base::list(
        tibble::tibble(time_id = base::unlist(vec_time_ids))
      )
    )

  return(res)
}
