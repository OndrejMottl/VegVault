#' @title Build the trait derivations fixture
#' @description
#' Build a small synthetic rule registry for the `trait_derivations`
#' contract, for tests and for producers checking their registry. All
#' values are invented; none comes from a real registry.
#' @param contract
#' The `trait_derivations` contract, as returned by
#' `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD`. Checked but not used: the registry file
#' has a fixed name without a date.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' one rule derives by an operation the contract does not allow
#' (`value_not_allowed`).
#' @return
#' A named list with one tibble, named by the contract's fixed file name
#' (`trait_derivations.csv`).
#' @details
#' Two reciprocal rules. The trait fixtures cite no derivation rule, so
#' these rules only need to satisfy the contract. The result is identical
#' on every call. Aborts when `contract` is not the `trait_derivations`
#' contract.
build_trait_derivations_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "trait_derivations.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(
      purrr::pluck(contract, "contract_id"),
      "trait_derivations"
    ),
    msg = "'contract' must be the trait_derivations contract."
  )

  assertthat::assert_that(
    base::is.character(date_file),
    base::length(date_file) == 1L,
    !base::is.na(date_file),
    stringr::str_detect(date_file, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"),
    msg = "'date_file' must be one date written YYYY-MM-DD."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  data_rules <-
    tibble::tibble(
      derivation_rule_key = c("sla_to_lma", "synthetic_to_inverse"),
      rule_version = "1.0.0",
      input_unit = c("mm2 mg-1", "m"),
      output_unit = c("mg/mm2", "m-1"),
      trait_dimension = c("mass_per_area", "inverse_length"),
      operation = "reciprocal",
      multiplier = 1,
      evidence = "Synthetic rule"
    )

  # The one defect, when asked for: an operation the producer cannot apply
  data_rules_final <-
    if (
      flag_broken
    ) {
      dplyr::mutate(
        data_rules,
        operation = c("reciprocal", "multiply")
      )
    } else {
      data_rules
    }

  res <-
    base::list(data_rules_final) |>
    rlang::set_names(
      purrr::chuck(contract, "file", "name_templates")[1]
    )

  return(res)
}
