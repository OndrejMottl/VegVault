save_trait_rules <- function(
    con,
    producer_root = base::file.path(
      base::dirname(here::here()),
      "VegVault-Trait_data"
    )) {
  path_registry <- base::file.path(producer_root, "config", "trait_units")

  data_conversion <-
    readr::read_csv(
      base::file.path(path_registry, "unit_conversions.csv"),
      col_types = readr::cols(.default = readr::col_character()),
      na = c("", "NA"),
      show_col_types = FALSE
    ) %>%
    dplyr::mutate(multiplier = base::as.numeric(.data$multiplier)) %>%
    dplyr::select(
      conversion_rule_key, rule_version, source_provider, source_trait_id,
      source_dataset_key, normalized_original_unit, standardized_unit,
      trait_dimension, operation, multiplier, evidence
    )

  data_derivation <-
    readr::read_csv(
      base::file.path(path_registry, "trait_derivations.csv"),
      col_types = readr::cols(.default = readr::col_character()),
      show_col_types = FALSE
    ) %>%
    dplyr::mutate(multiplier = base::as.numeric(.data$multiplier))

  add_missing_rules <- function(data_registry, table, key, id) {
    data_database <- dplyr::collect(dplyr::tbl(con, table))
    data_new <-
      data_registry %>%
      dplyr::filter(!.data[[key]] %in% data_database[[key]])

    if (nrow(data_new) > 0L) {
      save_table_rows(conn = con, data = data_new, table_name = table)
    }

    data_after <- dplyr::collect(dplyr::tbl(con, table))
    data_actual <-
      data_after %>%
      dplyr::select(-dplyr::all_of(id)) %>%
      dplyr::semi_join(data_registry, by = key) %>%
      dplyr::arrange(.data[[key]])
    data_expected <- data_registry %>% dplyr::arrange(.data[[key]])

    if (!base::isTRUE(base::all.equal(
      data_actual,
      data_expected,
      check.attributes = FALSE
    ))) {
      cli::cli_abort("Database rule registry conflicts with producer registry.")
    }
    return(data_after)
  }

  list(
    conversions = add_missing_rules(
      data_conversion, "TraitUnitConversion", "conversion_rule_key",
      "trait_unit_conversion_id"
    ),
    derivations = add_missing_rules(
      data_derivation, "TraitDerivation", "derivation_rule_key",
      "trait_derivation_id"
    )
  )
}
