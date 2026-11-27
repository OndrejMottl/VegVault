#' @title Build the BIEN traits fixture
#' @description
#' Build a small synthetic artefact for the `bien_traits` contract, for
#' tests and for producers checking their export. All values are invented;
#' none comes from a real dataset.
#' @param contract
#' The `bien_traits` contract, as returned by `load_producer_contract()`.
#' @param date_file
#' Character scalar `YYYY-MM-DD` used for the date in the file names.
#' @param flag_broken
#' Logical. If `TRUE`, the fixture breaks exactly one rule of the contract:
#' an older copy of part 1, dated the day before `date_file` and holding
#' other measurements, is included as well (`file_duplicate`).
#' @return
#' A named list with one tibble per part, named by the file name it is
#' saved under: the contract's file-name template filled with the part
#' number, the date and `rlang::hash()` of the tibble.
#' @details
#' Parts 0, 1 and 2 with two published measurements each, of whole-plant
#' height (m) and leaf area (mm2); one measurement has no coordinates. The
#' rule keys exist in the producer's registry
#' `config/trait_units/unit_conversions.csv`. The result is identical on
#' every call. Aborts when `contract` is not the `bien_traits` contract.
build_bien_traits_fixture <- function(
  contract = load_producer_contract(
    path_contract = here::here(
      "Data", "Contracts", "bien_traits.yml"
    )
  ),
  date_file = "2000-01-01",
  flag_broken = FALSE
) {
  assertthat::assert_that(
    base::identical(purrr::pluck(contract, "contract_id"), "bien_traits"),
    msg = "'contract' must be the bien_traits contract."
  )

  assertthat::assert_that(
    base::is.logical(flag_broken),
    base::length(flag_broken) == 1L,
    !base::is.na(flag_broken),
    msg = "'flag_broken' must be TRUE or FALSE."
  )

  data_traits <-
    tibble::tibble(
      source_provider = "BIEN",
      source_dataset_key = NA_character_,
      source_record_id = c(
        "bt0001", "bt0002", "bt0003", "bt0004", "bt0005", "bt0006"
      ),
      source_trait_id = c(
        "whole plant height", "leaf area", "whole plant height",
        "leaf area", "whole plant height", "leaf area"
      ),
      original_value_string = c("12", "850", "0.4", "1520", "25", "64"),
      original_unit = c("m", "mm2", "m", "mm2", "m", "mm2"),
      normalized_original_unit = c("m", "mm2", "m", "mm2", "m", "mm2"),
      conversion_rule_key = c(
        "bien_height", "bien_leaf_area", "bien_height",
        "bien_leaf_area", "bien_height", "bien_leaf_area"
      ),
      conversion_status = "identity",
      disposition = "published",
      derivation_rule_key = NA_character_,
      trait_value = c(12, 850, 0.4, 1520, 25, 64),
      trait_unit = c("m", "mm2", "m", "mm2", "m", "mm2"),
      id = c("bt0001", "bt0002", "bt0003", "bt0004", "bt0005", "bt0006"),
      project_pi = c(
        "Synthetic PI A", "Synthetic PI A", NA,
        "Synthetic PI B", "Synthetic PI B", "Synthetic PI B"
      ),
      source_citation = c("Synthetic citation A", NA, NA, NA, NA, NA),
      longitude = c(-60.1, -60.1, NA, 10.2, 10.2, 25.1),
      latitude = c(-10.1, -10.1, NA, 50.1, 50.1, 70.1),
      scrubbed_species_binomial = c(
        "Synthetica alpha", "Synthetica alpha", "Synthetica beta",
        "Synthetica beta", "Synthetica delta", "Synthetica delta"
      ),
      trait_domain = c(
        "Plant height", "Leaf Area", "Plant height", "Leaf Area",
        "Plant height", "Leaf Area"
      ),
      trait_full_name = c(
        "Plant height vegetative", "Leaf area", "Plant height vegetative",
        "Leaf area", "Plant height vegetative", "Leaf area"
      )
    )

  # Split by row order into parts 0, 1 and 2, as the producer does
  list_parts_current <-
    base::list(
      dplyr::slice(data_traits, 1:2),
      dplyr::slice(data_traits, 3:4),
      dplyr::slice(data_traits, 5:6)
    )

  # The one defect, when asked for: a stale copy of part 1 from an earlier
  #   run, with other measurements, is selected with the current one
  data_part_stale <-
    dplyr::slice(data_traits, 3:4) |>
    dplyr::mutate(
      source_record_id = c("bt9003", "bt9004"),
      id = c("bt9003", "bt9004")
    )

  date_stale <-
    base::format(base::as.Date(date_file) - 1, "%Y-%m-%d")

  list_parts <-
    if (
      flag_broken
    ) {
      c(list_parts_current, base::list(data_part_stale))
    } else {
      list_parts_current
    }

  vec_partitions <-
    if (
      flag_broken
    ) {
      c(0L, 1L, 2L, 1L)
    } else {
      c(0L, 1L, 2L)
    }

  vec_dates <-
    if (
      flag_broken
    ) {
      c(base::rep(date_file, 3L), date_stale)
    } else {
      base::rep(date_file, 3L)
    }

  name_template <-
    purrr::chuck(contract, "file", "name_templates")[1]

  # Indexed rather than pmap() with ..1: targets warns on ..1 when it scans
  #   the functions a pipeline uses
  vec_names <-
    purrr::map_chr(
      .x = base::seq_along(list_parts),
      .f = ~ build_producer_file_name(
        name_template = name_template,
        date = vec_dates[.x],
        hash = rlang::hash(list_parts[[.x]]),
        partition = vec_partitions[.x]
      )
    )

  res <-
    list_parts |>
    rlang::set_names(vec_names)

  return(res)
}
