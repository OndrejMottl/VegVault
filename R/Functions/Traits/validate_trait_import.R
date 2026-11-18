validate_trait_import <- function(data_source) {
  vec_required <-
    c(
      "source_provider", "source_record_id", "source_trait_id",
      "dataset_name", "sample_name", "trait_name", "taxon_name",
      "trait_value", "trait_unit", "conversion_rule_key",
      "derivation_rule_key"
    )
  vec_missing <- base::setdiff(vec_required, base::names(data_source))
  if (base::length(vec_missing) > 0L) {
    cli::cli_abort("Canonical trait import is missing: {vec_missing}.")
  }
  if (
    base::any(!base::is.finite(data_source$trait_value)) ||
      base::any(base::is.na(data_source$trait_unit)) ||
      base::any(base::is.na(data_source$conversion_rule_key))
  ) {
    cli::cli_abort("Trait imports require finite values, units, and rules.")
  }

  data_unit_conflicts <-
    data_source %>%
    dplyr::distinct(trait_name, trait_unit) %>%
    dplyr::count(.data$trait_name, name = "n_units") %>%
    dplyr::filter(.data$n_units != 1L)
  if (nrow(data_unit_conflicts) > 0L) {
    cli::cli_abort("A trait may not be imported with conflicting units.")
  }

  data_duplicates <-
    data_source %>%
    dplyr::count(
      .data$dataset_name, .data$sample_name,
      .data$trait_name, .data$taxon_name,
      name = "n_records"
    ) %>%
    dplyr::filter(.data$n_records != 1L)
  if (nrow(data_duplicates) > 0L) {
    cli::cli_abort("Canonical trait database keys must be unique.")
  }

  invisible(data_source)
}
