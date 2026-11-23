#' @title Build the trait unit conversions fixture
#' @description
#' Build a small synthetic rule registry for the `trait_unit_conversions`
#' contract, for tests and for producers checking their registry. All
#' values are invented; none comes from a real registry.
#' @param contract
#' The `trait_unit_conversions` contract, as returned by
#' `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD`. Checked but not used: the registry file
#' has a fixed name without a date.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' two rules share `conversion_rule_key` (`key_duplicate`).
#' @return
#' A named list with one tibble, named by the contract's fixed file name
#' (`unit_conversions.csv`).
#' @details
#' Six rules: the five rules the TRY and BIEN trait fixtures cite
#' (`build_try_traits_fixture()`, `build_bien_traits_fixture()`) and one
#' rule limited to one TRY dataset, so that `source_dataset_key` has a
#' value and a missing value. The result is identical on every call.
#' Aborts when `contract` is not the `trait_unit_conversions` contract.
build_trait_unit_conversions_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "trait_unit_conversions.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(
      purrr::pluck(contract, "contract_id"),
      "trait_unit_conversions"
    ),
    msg = "'contract' must be the trait_unit_conversions contract."
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
      conversion_rule_key = c(
        "try_height_m", "try_height_cm_dataset_90",
        "try_leaf_area_3114_mm2", "try_leaf_area_3114_cm2",
        "bien_height", "bien_leaf_area"
      ),
      rule_version = "1.0.0",
      source_provider = c("TRY", "TRY", "TRY", "TRY", "BIEN", "BIEN"),
      source_trait_id = c(
        "3106", "3106", "3114", "3114", "whole plant height", "leaf area"
      ),
      source_dataset_key = c(NA, "90", NA, NA, NA, NA),
      normalized_original_unit = c("m", "cm", "mm2", "cm2", "m", "mm2"),
      standardized_unit = c("m", "m", "mm2", "mm2", "m", "mm2"),
      trait_dimension = c(
        "length", "length", "area", "area", "length", "area"
      ),
      operation = c(
        "identity", "multiply", "identity", "multiply", "identity",
        "identity"
      ),
      multiplier = c(1, 0.01, 1, 100, 1, 1),
      evidence = "Synthetic rule"
    )

  # The one defect, when asked for: two rules share a key
  data_rules_final <-
    if (
      flag_broken
    ) {
      dplyr::mutate(
        data_rules,
        conversion_rule_key = base::replace(
          conversion_rule_key,
          2L,
          "try_height_m"
        )
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
