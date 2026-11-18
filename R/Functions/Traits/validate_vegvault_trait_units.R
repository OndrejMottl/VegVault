validate_vegvault_trait_units <- function(
    con,
    audit_directory = here::here(
      "Data", "Temp", "trait_database_audit"
    ),
    scoped_build = TRUE) {
  vec_required_tables <-
    c(
      "TraitsDomain", "Traits", "TraitsValue",
      "TraitUnitConversion", "TraitDerivation", "version_control"
    )
  if (!all(vec_required_tables %in% DBI::dbListTables(con))) {
    cli::cli_abort("VegVault 2 trait schema is incomplete.")
  }

  version <-
    dplyr::tbl(con, "version_control") %>%
    dplyr::select(.data$version) %>%
    dplyr::collect() %>%
    dplyr::slice_tail(n = 1L) %>%
    purrr::chuck("version")
  if (!identical(version, "2.0.0")) {
    cli::cli_abort("Trait-unit validation requires database version 2.0.0.")
  }

  data_fk <- DBI::dbGetQuery(con, "PRAGMA foreign_key_check")
  if (nrow(data_fk) > 0L) {
    cli::cli_abort("Foreign-key validation failed.")
  }

  data_values <-
    dplyr::tbl(con, "TraitsValue") %>%
    dplyr::collect()
  if (
    any(!is.finite(data_values$trait_value)) ||
      any(is.na(data_values$trait_unit_conversion_id))
  ) {
    cli::cli_abort("Published trait values contain invalid values or rules.")
  }

  data_duplicates <-
    data_values %>%
    dplyr::count(
      .data$trait_id, .data$dataset_id, .data$sample_id, .data$taxon_id,
      name = "n_records"
    ) %>%
    dplyr::filter(.data$n_records > 1L)
  if (nrow(data_duplicates) > 0L) {
    cli::cli_abort("TraitsValue contains duplicate database keys.")
  }

  n_known_corrections <-
    data_values %>%
    dplyr::inner_join(
      dplyr::tbl(con, "TraitUnitConversion") %>%
        dplyr::select(
          .data$trait_unit_conversion_id,
          .data$conversion_rule_key
        ) %>%
        dplyr::collect(),
      by = "trait_unit_conversion_id"
    ) %>%
    dplyr::filter(
      .data$conversion_rule_key %in%
        c("try_leaf_area_below_cm2", "try_leaf_area_alpine_cm2")
    ) %>%
    nrow()
  if (n_known_corrections != 3632L) {
    cli::cli_abort("The 3,632 known TRY Leaf Area corrections did not reconcile.")
  }

  vec_audit_paths <-
    base::list.files(audit_directory, pattern = "[.]qs$", full.names = TRUE)
  if (length(vec_audit_paths) > 0L) {
    n_audit <- sum(purrr::map_int(vec_audit_paths, ~ nrow(qs::qread(.x))))
    if (n_audit != nrow(data_values)) {
      cli::cli_abort("Database-keyed audit rows do not match TraitsValue rows.")
    }
  }

  if (isTRUE(scoped_build)) {
    n_abiotic <-
      dplyr::tbl(con, "AbioticData") %>%
      dplyr::summarise(n = dplyr::n()) %>%
      dplyr::collect() %>%
      purrr::chuck("n")
    n_gridpoint_types <-
      dplyr::tbl(con, "DatasetTypeID") %>%
      dplyr::filter(.data$dataset_type == "gridpoints") %>%
      dplyr::summarise(n = dplyr::n()) %>%
      dplyr::collect() %>%
      purrr::chuck("n")
    if (n_abiotic != 0L || n_gridpoint_types != 0L) {
      cli::cli_abort("Scoped scripts 01-05 build contains later-stage data.")
    }
  }

  invisible(TRUE)
}
