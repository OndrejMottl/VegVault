#' @title Summarise trait values by taxon
#' @description
#' Average the trait values of the trait rows of `load_trait_example()` per
#' taxon.
#' @param data_trait_example_raw
#' A data frame as returned by `load_trait_example()`, with at least
#' `dataset_type`, `taxon_id_trait` and `trait_value`.
#' @return
#' A tibble with one row per taxon with trait values: `taxon_id_trait` and
#' `trait_value_mean` (numeric), sorted by `taxon_id_trait`.
#' @details
#' Missing trait values are ignored. Aborts when a required column is
#' missing.
#' @examples
#' \dontrun{
#' data_trait_by_taxon <-
#'   summarise_trait_by_taxon(
#'     data_trait_example_raw = data_trait_example_raw
#'   )
#' }
summarise_trait_by_taxon <- function(data_trait_example_raw) {
  validate_data_columns(
    data_source = data_trait_example_raw,
    vec_columns_required = c("dataset_type", "taxon_id_trait", "trait_value"),
    name_argument = "data_trait_example_raw"
  )

  res <-
    data_trait_example_raw |>
    dplyr::filter(dataset_type == "traits") |>
    tidyr::drop_na(trait_value) |>
    dplyr::group_by(taxon_id_trait) |>
    dplyr::summarise(
      trait_value_mean = base::mean(trait_value),
      .groups = "drop"
    ) |>
    dplyr::arrange(taxon_id_trait)

  return(res)
}
