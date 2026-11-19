#' @title Prepare vegetation plots with their richness and climate
#' @description
#' Combine the vegetation plots of `load_plot_climate()` with the abiotic
#' value of their linked gridpoint and the number of their taxa.
#' @param data_plot_climate_raw
#' A data frame as returned by `load_plot_climate()`, with at least
#' `dataset_type`, `sample_id`, `sample_id_link`, `coord_long`,
#' `coord_lat`, `taxon_id`, `value`, `abiotic_variable_unit` and
#' `abiotic_value`.
#' @return
#' A tibble with one row per vegetation plot sample with at least two
#' taxa present (value above zero) and a linked abiotic value: `sample_id`,
#' `coord_long`, `coord_lat`, `n_taxa` (integer), `abiotic_variable_unit`
#' and `abiotic_value`, sorted by `sample_id`.
#' @details
#' Plots with one taxon are dropped, as in v1, because the example shows
#' the data for a joint species distribution model. Plots without a linked
#' abiotic value are dropped too; v1 kept them and drew them in the grey of
#' missing values. Aborts when a required column is missing.
#' @examples
#' \dontrun{
#' data_plot_climate <-
#'   prepare_plot_climate(data_plot_climate_raw = data_plot_climate_raw)
#' }
prepare_plot_climate <- function(data_plot_climate_raw) {
  validate_data_columns(
    data_source = data_plot_climate_raw,
    vec_columns_required = c(
      "dataset_type", "sample_id", "sample_id_link", "coord_long",
      "coord_lat", "taxon_id", "value", "abiotic_variable_unit",
      "abiotic_value"
    ),
    name_argument = "data_plot_climate_raw"
  )

  data_climate <-
    data_plot_climate_raw |>
    dplyr::filter(dataset_type == "gridpoints") |>
    dplyr::distinct(sample_id_link, abiotic_variable_unit, abiotic_value) |>
    tidyr::drop_na()

  data_richness <-
    data_plot_climate_raw |>
    dplyr::filter(
      dataset_type == "vegetation_plot",
      value > 0
    ) |>
    dplyr::distinct(sample_id, coord_long, coord_lat, taxon_id) |>
    tidyr::drop_na() |>
    dplyr::count(sample_id, coord_long, coord_lat, name = "n_taxa") |>
    dplyr::filter(n_taxa > 1)

  res <-
    data_richness |>
    dplyr::inner_join(
      data_climate,
      by = dplyr::join_by(sample_id == sample_id_link),
      relationship = "one-to-one"
    ) |>
    dplyr::mutate(n_taxa = base::as.integer(n_taxa)) |>
    dplyr::arrange(sample_id)

  return(res)
}
