#' @title Build the value rules of the abiotic data from the contracts
#' @description
#' Collect, from the producer contracts of the climate and soil artefacts,
#' the rules that the abiotic values and variable labels of a built
#' database must satisfy: one rule per artefact and variable.
#' @param path_contract_present
#' Character scalar. Path of the `chelsa_neoclimate` contract. Default: the
#' contract in `Data/Contracts/`.
#' @param path_contract_past
#' Character scalar. Path of the `chelsa_trace21k_palaeoclimate` contract.
#' Default: the contract in `Data/Contracts/`.
#' @param path_contract_soil
#' Character scalar. Path of the `hwsd_soil` contract. Default: the
#' contract in `Data/Contracts/`.
#' @return
#' A tibble with one row per artefact and variable, in contract order:
#' \itemize{
#'   \item `artefact_id`, `variable`: the contract and the variable name
#'     stored in `AbioticVariable.abiotic_variable_name`;
#'   \item `unit`, `details`: the unit and description the import writes
#'     to `abiotic_variable_unit` and `measure_details` (`details` is
#'     missing for the soil variable, whose detail the contract gives only
#'     in prose);
#'   \item `age_min`, `age_max`: the sample ages, in years before 1950,
#'     whose values come from the artefact (`-Inf` and `Inf` for soil);
#'   \item `range_min`, `range_max`, `flag_min_inclusive`,
#'     `flag_max_inclusive`: the plausible range (`-Inf` and `Inf` when
#'     the contract sets none);
#'   \item `list_forbidden`, `list_allowed`: list columns of numeric
#'     vectors, empty when the contract sets none;
#'   \item `flag_whole_number`: whether every value must be a whole number.
#' }
#' @details
#' The present-day artefact gives the values at age 0 and the
#' palaeoclimate artefact those of the other gridpoint ages
#' (`build_gridpoint_ages()`), because the import skips time slice 20,
#' age 0, of CHELSA-TraCE21k (contract of `chelsa_trace21k_palaeoclimate`).
#' The checks of the value column are combined with the checks of each
#' variable; the soil variable is the single allowed value of `var_name`.
#' Aborts when a contract lacks a field these rules need, or when the two
#' climate contracts give one variable different units or descriptions,
#' because the database stores one label per variable.
#' @seealso [diagnose_abiotic_values()], [diagnose_abiotic_variables()]
#' @examples
#' \dontrun{
#' build_abiotic_value_rules()
#' }
build_abiotic_value_rules <- function(
  path_contract_present = here::here(
    "Data", "Contracts", "chelsa_neoclimate.yml"
  ),
  path_contract_past = here::here(
    "Data", "Contracts", "chelsa_trace21k_palaeoclimate.yml"
  ),
  path_contract_soil = here::here("Data", "Contracts", "hwsd_soil.yml")
) {
  contract_present <-
    load_producer_contract(path_contract = path_contract_present)

  contract_past <-
    load_producer_contract(path_contract = path_contract_past)

  contract_soil <-
    load_producer_contract(path_contract = path_contract_soil)

  # Age 0 comes from the present day; the past covers the other time steps
  vec_ages_past <-
    build_gridpoint_ages(path_contract = path_contract_past) |>
    base::setdiff(0)

  # The checks of the value column apply to every variable
  list_checks_present <-
    select_contract_column(
      contract = contract_present,
      column = purrr::chuck(contract_present, "variables", "value_column")
    ) |>
    purrr::chuck("checks")

  list_checks_past <-
    select_contract_column(
      contract = contract_past,
      column = purrr::chuck(contract_past, "variables", "value_column")
    ) |>
    purrr::chuck("checks")

  data_present <-
    purrr::map(
      .x = purrr::chuck(contract_present, "variables", "table"),
      .f = ~ build_abiotic_rule(
        artefact_id = purrr::chuck(contract_present, "contract_id"),
        variable = purrr::chuck(.x, "variable"),
        unit = purrr::chuck(.x, "unit"),
        details = purrr::chuck(.x, "description"),
        age_min = 0,
        age_max = 0,
        list_checks = utils::modifyList(
          list_checks_present,
          purrr::pluck(.x, "checks", .default = base::list())
        )
      )
    ) |>
    dplyr::bind_rows()

  data_past <-
    purrr::map(
      .x = purrr::chuck(contract_past, "variables", "table"),
      .f = ~ build_abiotic_rule(
        artefact_id = purrr::chuck(contract_past, "contract_id"),
        variable = purrr::chuck(.x, "variable"),
        unit = purrr::chuck(.x, "unit"),
        details = purrr::chuck(.x, "description"),
        age_min = base::min(vec_ages_past),
        age_max = base::max(vec_ages_past),
        list_checks = utils::modifyList(
          list_checks_past,
          purrr::pluck(.x, "checks", .default = base::list())
        )
      )
    ) |>
    dplyr::bind_rows()

  # The soil variable is the one allowed value of var_name
  vec_soil_variables <-
    select_contract_column(contract = contract_soil, column = "var_name") |>
    purrr::pluck("checks", "allowed_values") |>
    base::unlist()

  if (
    base::length(vec_soil_variables) != 1L
  ) {
    cli::cli_abort(
      "The contract {.file {path_contract_soil}} must allow exactly one
      {.field var_name}."
    )
  }

  list_soil_value <-
    select_contract_column(contract = contract_soil, column = "value")

  data_soil <-
    build_abiotic_rule(
      artefact_id = purrr::chuck(contract_soil, "contract_id"),
      variable = vec_soil_variables,
      unit = purrr::chuck(list_soil_value, "unit"),
      details = NA_character_,
      age_min = -Inf,
      age_max = Inf,
      list_checks = purrr::chuck(list_soil_value, "checks")
    )

  # The database stores one unit and description per variable
  vec_conflicts <-
    dplyr::bind_rows(data_present, data_past) |>
    dplyr::group_by(variable) |>
    dplyr::filter(
      dplyr::n_distinct(unit) > 1L | dplyr::n_distinct(details) > 1L
    ) |>
    dplyr::pull(variable) |>
    base::unique()

  if (
    base::length(vec_conflicts) > 0L
  ) {
    cli::cli_abort(
      "The climate contracts give {.val {vec_conflicts}} different units or
      descriptions."
    )
  }

  res <-
    dplyr::bind_rows(data_present, data_past, data_soil)

  return(res)
}
