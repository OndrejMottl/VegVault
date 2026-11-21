# The source tables of the five valid contract fixtures (sPlotOpen, BIEN
#   plots with a stand-in plot id, FOSSILPOL, TRY and BIEN traits), with test
#   source entries, and the unit-conversion rules their trait values use
#   (no derivation rules). Returns a list with `list_source_tables`,
#   `data_unit_conversions` and `data_trait_derivations`.
build_test_database_sources <- function() {
  data_bien <-
    load_valid_fixture(id_artefact = "bien_plots")

  list_source_tables <-
    base::list(
      splot = prepare_splot_tables(
        data_splot = load_valid_fixture(id_artefact = "splot_plots"),
        list_source = build_test_source_config(
          dataset_type = "vegetation_plot",
          dataset_source_type = "sPlotOpen"
        ),
        verbose = FALSE
      ),
      bien_plots = prepare_bien_plot_tables(
        data_bien = dplyr::mutate(
          data_bien,
          plot_id = stringr::str_c("p", base::seq_len(base::nrow(data_bien)))
        ),
        list_source = build_test_source_config(
          dataset_type = "vegetation_plot",
          dataset_source_type = "BIEN"
        ),
        verbose = FALSE
      ),
      fossilpol = prepare_fossilpol_tables(
        data_assembly = load_valid_fixture(id_artefact = "fossilpol_assembly"),
        data_age_uncertainty = load_valid_fixture(
          id_artefact = "fossilpol_age_uncertainty"
        ),
        list_source = build_test_source_config(
          dataset_type = "fossil_pollen_archive",
          dataset_source_type = "FOSSILPOL"
        ),
        verbose = FALSE
      ),
      try = prepare_trait_tables(
        data_traits = load_valid_fixture(id_artefact = "try_traits"),
        list_columns = base::list(
          sample_id = "observation_id",
          data_source_desc = "dataset",
          data_source_reference = "reference_source",
          taxon_name = "acc_species_name",
          sample_references = c(
            "dataset_reference_citation",
            "record_reference"
          )
        ),
        name_prefix = "try",
        list_source = build_test_source_config(
          dataset_type = "traits",
          dataset_source_type = "TRY"
        ),
        verbose = FALSE
      ),
      bien_traits = prepare_trait_tables(
        data_traits = load_valid_fixture(id_artefact = "bien_traits"),
        list_columns = base::list(
          sample_id = "id",
          data_source_desc = "project_pi",
          data_source_reference = "source_citation",
          taxon_name = "scrubbed_species_binomial",
          sample_references = base::character(0)
        ),
        name_prefix = "bien_traits",
        list_source = build_test_source_config(
          dataset_type = "traits",
          dataset_source_type = "BIEN"
        ),
        verbose = FALSE
      )
    )

  data_unit_conversions <-
    list_source_tables |>
    purrr::map(.f = ~ purrr::chuck(.x, "trait_values")) |>
    dplyr::bind_rows() |>
    dplyr::distinct(conversion_rule_key, trait_unit) |>
    dplyr::mutate(
      rule_version = "1",
      source_provider = "test",
      source_trait_id = "1",
      source_dataset_key = NA_character_,
      normalized_original_unit = trait_unit,
      standardized_unit = trait_unit,
      trait_dimension = "test",
      operation = "identity",
      multiplier = 1,
      evidence = "test rule"
    ) |>
    dplyr::select(-trait_unit)

  data_trait_derivations <-
    tibble::tibble(
      derivation_rule_key = base::character(0),
      rule_version = base::character(0),
      input_unit = base::character(0),
      output_unit = base::character(0),
      trait_dimension = base::character(0),
      operation = base::character(0),
      multiplier = base::double(0),
      evidence = base::character(0)
    )

  res <-
    base::list(
      list_source_tables = list_source_tables,
      data_unit_conversions = data_unit_conversions,
      data_trait_derivations = data_trait_derivations
    )

  return(res)
}
