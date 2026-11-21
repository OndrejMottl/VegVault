#' @title Build the TRY traits fixture
#' @description
#' Build a small synthetic artefact for the `try_traits` contract, for
#' tests and for producers checking their export. All values are invented;
#' none comes from a real dataset.
#' @param contract
#' The `try_traits` contract, as returned by `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD` used for the date in the file name.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' one record has `disposition` quarantined (`value_not_allowed`).
#' @return
#' A named list with one tibble, named by the file name it is saved under:
#' the contract's file-name template filled with `date_file` and
#' `rlang::hash()` of the tibble.
#' @details
#' Four published records of two traits (leaf area in mm2, plant height in
#' m) for two observations; one record was converted from cm2, one
#' observation has no coordinates, no dataset key and no record reference
#' (`record_reference`). The rule keys exist in
#' the producer's registry `config/trait_units/unit_conversions.csv`. The
#' result is identical on every call. Aborts when `contract` is not the
#' `try_traits` contract.
build_try_traits_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "try_traits.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(purrr::pluck(contract, "contract_id"), "try_traits"),
    msg = "'contract' must be the try_traits contract."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  data_traits <-
    tibble::tibble(
      source_provider = "TRY",
      source_dataset_key = c("90", "90", NA, NA),
      source_record_id = c("r1", "r2", "r3", "r4"),
      source_trait_id = c("3114", "3106", "3114", "3106"),
      original_value_string = c("1250", "0.85", "13.1", "2.4"),
      original_unit = c("mm2", "m", "cm2", "m"),
      normalized_original_unit = c("mm2", "m", "cm2", "m"),
      conversion_rule_key = c(
        "try_leaf_area_3114_mm2", "try_height_m",
        "try_leaf_area_3114_cm2", "try_height_m"
      ),
      conversion_status = c("identity", "identity", "converted", "identity"),
      disposition = "published",
      derivation_rule_key = NA_character_,
      trait_value = c(1250, 0.85, 1310, 2.4),
      trait_unit = c("mm2", "m", "mm2", "m"),
      observation_id = c(5001L, 5001L, 5002L, 5002L),
      dataset = c(
        "Synthetic trait study A", "Synthetic trait study A",
        "Synthetic trait study B", "Synthetic trait study B"
      ),
      reference_source = c(
        "Synthetic reference A", "Synthetic reference A", NA, NA
      ),
      dataset_reference_citation = c(
        "Synthetic citation A", "Synthetic citation A", NA, NA
      ),
      record_reference = c(
        "Synthetic publication A", "Synthetic publication A", NA, NA
      ),
      longitude = c(10.05, 10.05, NA, NA),
      latitude = c(50.05, 50.05, NA, NA),
      acc_species_name = c(
        "Synthetica alpha", "Synthetica alpha",
        "Synthetica beta", "Synthetica beta"
      ),
      trait_domain = c(
        "Leaf Area", "Plant height", "Leaf Area", "Plant height"
      ),
      trait_full_name = c(
        "Leaf area", "Plant height vegetative",
        "Leaf area", "Plant height vegetative"
      )
    )

  # The one defect, when asked for: an unpublished record in the export
  data_traits_final <-
    if (
      flag_broken
    ) {
      dplyr::mutate(
        data_traits,
        disposition = c("published", "quarantined", "published", "published")
      )
    } else {
      data_traits
    }

  name_file <-
    build_producer_file_name(
      name_template = purrr::chuck(contract, "file", "name_templates")[1],
      date = date_file,
      hash = rlang::hash(data_traits_final)
    )

  res <-
    base::list(data_traits_final) |>
    rlang::set_names(name_file)

  return(res)
}
