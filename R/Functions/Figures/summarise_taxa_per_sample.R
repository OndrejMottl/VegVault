#' @title Summarise the number of taxa per sample
#' @description
#' Count the taxa present (value above zero) in each vegetation plot or
#' fossil pollen sample of `load_trait_example()`.
#' @param data_trait_example_raw
#' A data frame as returned by `load_trait_example()`, with at least
#' `dataset_type`, `dataset_id`, `sample_id`, `coord_long`, `coord_lat`,
#' `taxon_id` and `value`.
#' @return
#' A tibble with one row per sample with at least two taxa: `dataset_id`,
#' `sample_id`, `coord_long`, `coord_lat` and `n_taxa` (integer), sorted by
#' `dataset_id` and `sample_id`.
#' @details
#' Samples with one taxon are dropped, as in v1. Aborts when a required
#' column is missing.
#' @examples
#' \dontrun{
#' data_taxa_per_sample <-
#'   summarise_taxa_per_sample(
#'     data_trait_example_raw = data_trait_example_raw
#'   )
#' }
summarise_taxa_per_sample <- function(data_trait_example_raw) {
  validate_data_columns(
    data_source = data_trait_example_raw,
    vec_columns_required = c(
      "dataset_type", "dataset_id", "sample_id", "coord_long", "coord_lat",
      "taxon_id", "value"
    ),
    name_argument = "data_trait_example_raw"
  )

  res <-
    data_trait_example_raw |>
    dplyr::filter(
      dataset_type %in% c("vegetation_plot", "fossil_pollen_archive"),
      value > 0
    ) |>
    dplyr::distinct(dataset_id, sample_id, coord_long, coord_lat, taxon_id) |>
    tidyr::drop_na() |>
    dplyr::count(
      dataset_id,
      sample_id,
      coord_long,
      coord_lat,
      name = "n_taxa"
    ) |>
    dplyr::filter(n_taxa > 1) |>
    dplyr::mutate(n_taxa = base::as.integer(n_taxa)) |>
    dplyr::arrange(dataset_id, sample_id)

  return(res)
}
