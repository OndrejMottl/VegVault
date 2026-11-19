add_trait_value <- function(
    data_source,
    dataset_id,
    samples_id,
    traits_id,
    taxa_id,
    con) {
  validate_trait_import(data_source)

  data_conversion_id <-
    dplyr::tbl(con, "TraitUnitConversion") %>%
    dplyr::select(
      trait_unit_conversion_id,
      conversion_rule_key,
      standardized_unit
    ) %>%
    dplyr::collect()

  data_derivation_id <-
    dplyr::tbl(con, "TraitDerivation") %>%
    dplyr::select(
      trait_derivation_id,
      derivation_rule_key,
      output_unit
    ) %>%
    dplyr::collect()

  traits_value_audit <-
    data_source %>%
    dplyr::left_join(dataset_id, by = dplyr::join_by(dataset_name)) %>%
    dplyr::left_join(samples_id, by = dplyr::join_by(sample_name)) %>%
    dplyr::left_join(traits_id, by = dplyr::join_by(trait_name)) %>%
    dplyr::left_join(taxa_id, by = dplyr::join_by(taxon_name)) %>%
    dplyr::left_join(
      data_conversion_id,
      by = dplyr::join_by(conversion_rule_key)
    ) %>%
    dplyr::left_join(
      data_derivation_id,
      by = dplyr::join_by(derivation_rule_key)
    )

  vec_required_ids <-
    c(
      "trait_id",
      "dataset_id",
      "sample_id",
      "taxon_id",
      "trait_unit_conversion_id"
    )

  if (base::any(base::is.na(traits_value_audit[vec_required_ids]))) {
    cli::cli_abort("Trait import contains unresolved database or rule keys.")
  }

  vec_expected_unit <-
    dplyr::coalesce(
      traits_value_audit$output_unit,
      traits_value_audit$standardized_unit
    )

  if (!base::all(traits_value_audit$trait_unit == vec_expected_unit)) {
    cli::cli_abort("Trait values conflict with their registered final units.")
  }

  data_existing <-
    dplyr::tbl(con, "TraitsValue") %>%
    dplyr::select(trait_id, dataset_id, sample_id, taxon_id) %>%
    dplyr::collect()

  data_conflicts <-
    traits_value_audit %>%
    dplyr::semi_join(
      data_existing,
      by = dplyr::join_by(trait_id, dataset_id, sample_id, taxon_id)
    )

  if (nrow(data_conflicts) > 0L) {
    cli::cli_abort("Trait values already exist for one or more database keys.")
  }

  data_insert <-
    traits_value_audit %>%
    dplyr::select(
      trait_id,
      dataset_id,
      sample_id,
      taxon_id,
      trait_value,
      trait_unit_conversion_id,
      trait_derivation_id
    )

  if (nrow(data_insert) != nrow(data_source)) {
    cli::cli_abort("Trait row reconciliation failed before insertion.")
  }

  add_to_db(
    conn = con,
    data = data_insert,
    table_name = "TraitsValue",
    overwrite_test = TRUE
  )

  return(traits_value_audit)
}
