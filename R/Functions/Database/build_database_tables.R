#' @title Build the database tables of all sources with their ids
#' @description
#' Combine the source tables of every source, give every row its id and
#' resolve every foreign key in memory, and return the tables in the form
#' `save_vegvault_database()` writes.
#' @param list_source_tables
#' Named list, one element per source in the order of the build (for
#' example `splot`, `bien_plots`, `fossilpol`, `try`, `bien_traits`), each
#' the named list of tables of `build_source_table_template()`. Elements a
#' source does not use may be omitted.
#' @param data_unit_conversions
#' A data frame of the trait unit-conversion rules, with the columns of
#' `TraitUnitConversion` except its id.
#' @param data_trait_derivations
#' A data frame of the trait derivation rules, with the columns of
#' `TraitDerivation` except its id.
#' @param data_general_references
#' A data frame with `reference_detail` and `mandatory`: references of the
#' database itself, linked to nothing (the VegVault reference). Default:
#' none.
#' @return
#' A named list of tibbles named by schema table, with the columns of the
#' schema: `DatasetTypeID`, `DatasetSourceTypeID`, `DatasetSourcesID`,
#' `SamplingMethodID`, `References`, `DatasetSourceTypeReference`,
#' `DatasetSourcesReference`, `SamplingMethodReference`, `Datasets`,
#' `DatasetReferences`, `SampleSizeID`, `Samples`, `SampleReference`,
#' `DatasetSample`, `SampleUncertainty`, `Taxa`, `TaxonClassification`,
#' `TaxonReference`, `SampleTaxa`, `TraitsDomain`, `Traits`,
#' `TraitsReference`, `TraitUnitConversion`, `TraitDerivation`,
#' `TraitsValue`, `AbioticVariable`, `AbioticVariableReference` and
#' `AbioticData`.
#' @details
#' Ids of lookup tables and references follow the first source that uses a
#' value, then the value (`prepare_lookup_ids()`); ids of datasets and
#' samples follow the source, then the name. So the same inputs give the
#' same ids in every build. The general references come before every
#' source, so the VegVault reference gets id 1 as in v1.0.0. A reference is
#' mandatory when any of its uses is mandatory. The same text in two
#' sources (a taxon, a data source, a reference) is one row, as in v1.0.0.
#' Rule ids follow their rule keys.
#' Every foreign key is resolved with `prepare_table_foreign_key()`, so a
#' key without a parent aborts and names the table.
#' Every trait value must have its unit-conversion rule and, when it has a
#' derivation key, its derivation rule, and its unit must equal the unit
#' the rule produces (the derivation's output unit, or else the
#' conversion's standardised unit); otherwise the function aborts.
#' An abiotic variable used by several sources (present-day and
#' palaeoclimate) is one row and must have the same unit and details in
#' each; a sample has at most one value per variable. Either conflict
#' aborts. A taxon has at most one classification, and the taxon and its
#' species, genus and family must be taxa of the sources (the
#' classification source of `prepare_classification_tables()` adds its
#' rank names; it comes last, so they get ids after the taxa of the
#' sources). A repeated or unknown name aborts.
#' Aborts when `list_source_tables` is not a named list of source tables,
#' or when a table has other columns than the template.
#' @seealso [build_source_table_template()], [save_vegvault_database()]
#' @examples
#' \dontrun{
#' list_tables <-
#'   build_database_tables(
#'     list_source_tables = base::list(
#'       splot = list_splot_tables,
#'       try = list_try_tables
#'     ),
#'     data_unit_conversions = data_unit_conversions,
#'     data_trait_derivations = data_trait_derivations
#'   )
#' }
build_database_tables <- function(
  list_source_tables,
  data_unit_conversions,
  data_trait_derivations,
  data_general_references = tibble::tibble(
    reference_detail = base::character(0),
    mandatory = base::logical(0)
  )
) {
  list_template <-
    build_source_table_template()

  assertthat::assert_that(
    base::is.list(list_source_tables),
    base::length(list_source_tables) >= 1L,
    !base::is.null(base::names(list_source_tables)),
    base::all(base::nzchar(base::names(list_source_tables))),
    !base::anyDuplicated(base::names(list_source_tables)),
    base::all(purrr::map_lgl(.x = list_source_tables, .f = base::is.list)),
    msg = stringr::str_c(
      "`list_source_tables` must be a named list with one list of source ",
      "tables per source."
    )
  )

  vec_conversion_columns <-
    c(
      "conversion_rule_key", "rule_version", "source_provider",
      "source_trait_id", "source_dataset_key", "normalized_original_unit",
      "standardized_unit", "trait_dimension", "operation", "multiplier",
      "evidence"
    )

  vec_derivation_columns <-
    c(
      "derivation_rule_key", "rule_version", "input_unit", "output_unit",
      "trait_dimension", "operation", "multiplier", "evidence"
    )

  assertthat::assert_that(
    base::is.data.frame(data_unit_conversions),
    base::all(vec_conversion_columns %in% base::names(data_unit_conversions)),
    msg = "`data_unit_conversions` must hold the TraitUnitConversion columns."
  )

  assertthat::assert_that(
    base::is.data.frame(data_trait_derivations),
    base::all(vec_derivation_columns %in% base::names(data_trait_derivations)),
    msg = "`data_trait_derivations` must hold the TraitDerivation columns."
  )

  assertthat::assert_that(
    base::is.data.frame(data_general_references),
    base::all(
      c("reference_detail", "mandatory") %in%
        base::names(data_general_references)
    ),
    base::is.logical(dplyr::pull(data_general_references, mandatory)),
    msg = stringr::str_c(
      "`data_general_references` must hold `reference_detail` and a ",
      "logical `mandatory`."
    )
  )

  # Every table of every source must match the template exactly
  data_problems <-
    list_source_tables |>
    purrr::imap(
      .f = ~ {
        list_source <- .x

        name_source <- .y

        purrr::imap(
          .x = list_source,
          .f = ~ {
            vec_expected <-
              base::names(purrr::pluck(list_template, .y))

            vec_unknown <-
              if (
                base::is.null(vec_expected)
              ) {
                .y
              } else {
                base::setdiff(base::names(.x), vec_expected)
              }

            vec_missing <-
              base::setdiff(vec_expected, base::names(.x))

            tibble::tibble(
              source = name_source,
              table = .y,
              problem = c(
                stringr::str_c("unknown table or column ", vec_unknown),
                stringr::str_c("missing column ", vec_missing)
              )
            )
          }
        ) |>
          purrr::list_rbind()
      }
    ) |>
    purrr::list_rbind()

  if (
    base::nrow(data_problems) > 0L
  ) {
    vec_problems <-
      stringr::str_c(
        dplyr::pull(data_problems, source),
        " / ",
        dplyr::pull(data_problems, table),
        ": ",
        dplyr::pull(data_problems, problem)
      )

    cli::cli_abort(
      c(
        "The source tables do not match the template of
        {.fn build_source_table_template}.",
        rlang::set_names(
          utils::head(vec_problems, 10L),
          base::rep("x", base::length(utils::head(vec_problems, 10L)))
        )
      )
    )
  }

  # One table per element, all sources bound, with the position of the
  #   source that gives the id order
  list_bound <-
    list_template |>
    purrr::imap(
      .f = ~ {
        data_empty <- .x

        name_element <- .y

        list_source_tables |>
          base::unname() |>
          purrr::imap(
            .f = ~ dplyr::bind_rows(
              data_empty,
              purrr::pluck(.x, name_element)
            ) |>
              dplyr::mutate(source_order = .y)
          ) |>
          purrr::list_rbind()
      }
    )

  #--------------------------------------------------#
  # References and lookup tables -----
  #--------------------------------------------------#

  vec_reference_elements <-
    c(
      "source_type_references", "data_source_references",
      "sampling_method_references", "dataset_references",
      "sample_references", "taxon_references", "trait_references",
      "abiotic_variable_references"
    )

  data_reference_uses_sources <-
    vec_reference_elements |>
    purrr::map(
      .f = ~ dplyr::select(
        purrr::chuck(list_bound, .x),
        source_order, reference_detail, mandatory
      )
    ) |>
    purrr::list_rbind()

  # The general references come before every source (position 0)
  data_reference_uses <-
    dplyr::bind_rows(
      data_general_references |>
        dplyr::select(reference_detail, mandatory) |>
        dplyr::mutate(source_order = 0L),
      data_reference_uses_sources
    )

  data_reference_flags <-
    data_reference_uses |>
    dplyr::summarise(
      mandatory = base::any(mandatory),
      .by = reference_detail
    )

  data_references <-
    prepare_lookup_ids(
      data_values = data_reference_uses,
      vec_key_columns = "reference_detail",
      name_id = "reference_id",
      name_table = "References"
    ) |>
    dplyr::left_join(
      data_reference_flags,
      by = dplyr::join_by(reference_detail),
      relationship = "one-to-one"
    )

  data_datasets_bound <-
    purrr::chuck(list_bound, "datasets")

  data_dataset_types <-
    prepare_lookup_ids(
      data_values = data_datasets_bound,
      vec_key_columns = "dataset_type",
      name_id = "dataset_type_id",
      name_table = "DatasetTypeID"
    )

  data_source_types <-
    prepare_lookup_ids(
      data_values = dplyr::bind_rows(
        dplyr::select(data_datasets_bound, source_order, dataset_source_type),
        dplyr::select(
          purrr::chuck(list_bound, "source_type_references"),
          source_order, dataset_source_type
        )
      ),
      vec_key_columns = "dataset_source_type",
      name_id = "data_source_type_id",
      name_table = "DatasetSourceTypeID"
    )

  data_data_sources <-
    prepare_lookup_ids(
      data_values = dplyr::bind_rows(
        dplyr::select(data_datasets_bound, source_order, data_source_desc),
        dplyr::select(
          purrr::chuck(list_bound, "data_source_references"),
          source_order, data_source_desc
        )
      ),
      vec_key_columns = "data_source_desc",
      name_id = "data_source_id",
      name_table = "DatasetSourcesID"
    )

  data_sampling_methods <-
    prepare_lookup_ids(
      data_values = dplyr::bind_rows(
        dplyr::select(
          data_datasets_bound,
          source_order, sampling_method_details
        ),
        dplyr::select(
          purrr::chuck(list_bound, "sampling_method_references"),
          source_order, sampling_method_details
        )
      ),
      vec_key_columns = "sampling_method_details",
      name_id = "sampling_method_id",
      name_table = "SamplingMethodID"
    )

  data_samples_bound <-
    purrr::chuck(list_bound, "samples")

  data_sample_sizes <-
    prepare_lookup_ids(
      data_values = data_samples_bound,
      vec_key_columns = c("sample_size", "sample_size_description"),
      name_id = "sample_size_id",
      name_table = "SampleSizeID"
    )

  data_taxa <-
    prepare_lookup_ids(
      data_values = c(
        "taxa", "taxon_references", "sample_taxa", "trait_values"
      ) |>
        purrr::map(
          .f = ~ dplyr::select(
            purrr::chuck(list_bound, .x),
            source_order, taxon_name
          )
        ) |>
        purrr::list_rbind(),
      vec_key_columns = "taxon_name",
      name_id = "taxon_id",
      name_table = "Taxa"
    )

  # A trait domain has one unit, a trait one domain
  data_domain_units <-
    purrr::chuck(list_bound, "trait_domains") |>
    dplyr::distinct(trait_domain_name, trait_unit)

  data_trait_domains_named <-
    purrr::chuck(list_bound, "traits") |>
    dplyr::distinct(trait_name, trait_domain_name)

  vec_domains_repeated <-
    data_domain_units |>
    dplyr::count(trait_domain_name) |>
    dplyr::filter(n > 1L) |>
    dplyr::pull(trait_domain_name)

  vec_traits_repeated <-
    data_trait_domains_named |>
    dplyr::count(trait_name) |>
    dplyr::filter(n > 1L) |>
    dplyr::pull(trait_name)

  if (
    base::length(vec_domains_repeated) > 0L ||
      base::length(vec_traits_repeated) > 0L
  ) {
    cli::cli_abort(
      c(
        "Trait domains need one unit and traits one domain.",
        "x" = "Domains with several units: {.val {vec_domains_repeated}}.",
        "x" = "Traits with several domains: {.val {vec_traits_repeated}}."
      )
    )
  }

  data_trait_domains <-
    prepare_lookup_ids(
      data_values = purrr::chuck(list_bound, "trait_domains"),
      vec_key_columns = "trait_domain_name",
      name_id = "trait_domain_id",
      name_table = "TraitsDomain"
    ) |>
    dplyr::left_join(
      data_domain_units,
      by = dplyr::join_by(trait_domain_name),
      relationship = "one-to-one"
    )

  data_traits <-
    prepare_lookup_ids(
      data_values = c("traits", "trait_references", "trait_values") |>
        purrr::map(
          .f = ~ dplyr::select(
            purrr::chuck(list_bound, .x),
            source_order, trait_name
          )
        ) |>
        purrr::list_rbind(),
      vec_key_columns = "trait_name",
      name_id = "trait_id",
      name_table = "Traits"
    ) |>
    dplyr::left_join(
      data_trait_domains_named,
      by = dplyr::join_by(trait_name),
      relationship = "one-to-one"
    ) |>
    prepare_table_foreign_key(
      data_parent = dplyr::select(
        data_trait_domains,
        trait_domain_id, trait_domain_name
      ),
      vec_key_columns = "trait_domain_name",
      name_id = "trait_domain_id",
      name_table = "Traits",
      flag_allow_missing = TRUE
    )

  data_conversions <-
    prepare_table_ids(
      data_table = dplyr::select(
        data_unit_conversions,
        dplyr::all_of(vec_conversion_columns)
      ),
      vec_sort_columns = "conversion_rule_key",
      name_id = "trait_unit_conversion_id",
      name_table = "TraitUnitConversion"
    )

  data_derivations <-
    prepare_table_ids(
      data_table = dplyr::select(
        data_trait_derivations,
        dplyr::all_of(vec_derivation_columns)
      ),
      vec_sort_columns = "derivation_rule_key",
      name_id = "trait_derivation_id",
      name_table = "TraitDerivation"
    )

  # An abiotic variable has one unit and one description over its sources
  data_variable_labels <-
    purrr::chuck(list_bound, "abiotic_variables") |>
    dplyr::distinct(
      abiotic_variable_name, abiotic_variable_unit, measure_details
    )

  vec_variables_conflicting <-
    data_variable_labels |>
    dplyr::count(abiotic_variable_name) |>
    dplyr::filter(n > 1L) |>
    dplyr::pull(abiotic_variable_name)

  if (
    base::length(vec_variables_conflicting) > 0L
  ) {
    cli::cli_abort(
      "Abiotic variable{?s} with conflicting unit or details over the
      sources: {.val {vec_variables_conflicting}}."
    )
  }

  data_abiotic_variables <-
    prepare_lookup_ids(
      data_values = c(
        "abiotic_variables", "abiotic_variable_references", "abiotic_values"
      ) |>
        purrr::map(
          .f = ~ dplyr::select(
            purrr::chuck(list_bound, .x),
            source_order, abiotic_variable_name
          )
        ) |>
        purrr::list_rbind(),
      vec_key_columns = "abiotic_variable_name",
      name_id = "abiotic_variable_id",
      name_table = "AbioticVariable"
    ) |>
    dplyr::left_join(
      data_variable_labels,
      by = dplyr::join_by(abiotic_variable_name),
      relationship = "one-to-one"
    )

  #--------------------------------------------------#
  # Datasets and samples -----
  #--------------------------------------------------#

  # Dataset names and sample names are each unique over all sources, not
  #   only within one (a dataset and its sample may share a name)
  vec_dataset_names <-
    dplyr::pull(data_datasets_bound, dataset_name)

  vec_sample_names <-
    dplyr::pull(data_samples_bound, sample_name)

  vec_repeated_names <-
    c(
      vec_dataset_names[base::duplicated(vec_dataset_names)],
      vec_sample_names[base::duplicated(vec_sample_names)]
    )

  if (
    base::length(vec_repeated_names) > 0L
  ) {
    cli::cli_abort(
      c(
        "{base::length(vec_repeated_names)} dataset or sample name{?s}
        repeat{?s/} over the sources.",
        "x" = "First: {.val {utils::head(vec_repeated_names, 5L)}}."
      )
    )
  }

  data_datasets <-
    prepare_table_ids(
      data_table = data_datasets_bound,
      vec_sort_columns = c("source_order", "dataset_name"),
      name_id = "dataset_id",
      name_table = "Datasets"
    ) |>
    prepare_table_foreign_key(
      data_parent = data_dataset_types,
      vec_key_columns = "dataset_type",
      name_id = "dataset_type_id",
      name_table = "Datasets"
    ) |>
    prepare_table_foreign_key(
      data_parent = data_source_types,
      vec_key_columns = "dataset_source_type",
      name_id = "data_source_type_id",
      name_table = "Datasets"
    ) |>
    prepare_table_foreign_key(
      data_parent = data_data_sources,
      vec_key_columns = "data_source_desc",
      name_id = "data_source_id",
      name_table = "Datasets",
      flag_allow_missing = TRUE
    ) |>
    prepare_table_foreign_key(
      data_parent = data_sampling_methods,
      vec_key_columns = "sampling_method_details",
      name_id = "sampling_method_id",
      name_table = "Datasets",
      flag_allow_missing = TRUE
    )

  data_samples <-
    prepare_table_ids(
      data_table = data_samples_bound,
      vec_sort_columns = c("source_order", "sample_name"),
      name_id = "sample_id",
      name_table = "Samples"
    ) |>
    prepare_table_foreign_key(
      data_parent = data_sample_sizes,
      vec_key_columns = c("sample_size", "sample_size_description"),
      name_id = "sample_size_id",
      name_table = "Samples",
      flag_allow_missing = TRUE
    )

  data_dataset_ids <-
    dplyr::select(data_datasets, dataset_id, dataset_name)

  data_sample_ids <-
    dplyr::select(data_samples, sample_id, sample_name)

  data_taxon_ids <-
    dplyr::select(data_taxa, taxon_id, taxon_name)

  # A taxon has at most one classification; its ranks are taxa as well
  data_classification_bound <-
    purrr::chuck(list_bound, "taxon_classification")

  vec_classified_names <-
    dplyr::pull(data_classification_bound, taxon_name)

  vec_classified_repeated <-
    base::unique(
      vec_classified_names[base::duplicated(vec_classified_names)]
    )

  if (
    base::length(vec_classified_repeated) > 0L
  ) {
    cli::cli_abort(
      "TaxonClassification: {base::length(vec_classified_repeated)}
      tax{?on has/a have} more than one classification:
      {.val {utils::head(vec_classified_repeated, 5L)}}."
    )
  }

  data_taxon_classification <-
    data_classification_bound |>
    prepare_table_foreign_key(
      data_parent = data_taxon_ids,
      vec_key_columns = "taxon_name",
      name_id = "taxon_id",
      name_table = "TaxonClassification"
    ) |>
    prepare_table_foreign_key(
      data_parent = dplyr::select(
        data_taxon_ids,
        taxon_species = taxon_id,
        species_name = taxon_name
      ),
      vec_key_columns = "species_name",
      name_id = "taxon_species",
      name_table = "TaxonClassification",
      flag_allow_missing = TRUE
    ) |>
    prepare_table_foreign_key(
      data_parent = dplyr::select(
        data_taxon_ids,
        taxon_genus = taxon_id,
        genus_name = taxon_name
      ),
      vec_key_columns = "genus_name",
      name_id = "taxon_genus",
      name_table = "TaxonClassification",
      flag_allow_missing = TRUE
    ) |>
    prepare_table_foreign_key(
      data_parent = dplyr::select(
        data_taxon_ids,
        taxon_family = taxon_id,
        family_name = taxon_name
      ),
      vec_key_columns = "family_name",
      name_id = "taxon_family",
      name_table = "TaxonClassification",
      flag_allow_missing = TRUE
    ) |>
    dplyr::select(taxon_id, taxon_species, taxon_genus, taxon_family) |>
    dplyr::arrange(taxon_id)

  #--------------------------------------------------#
  # Links, values and trait values -----
  #--------------------------------------------------#

  data_trait_values <-
    purrr::chuck(list_bound, "trait_values") |>
    prepare_table_foreign_key(
      data_parent = data_dataset_ids,
      vec_key_columns = "dataset_name",
      name_id = "dataset_id",
      name_table = "TraitsValue"
    ) |>
    prepare_table_foreign_key(
      data_parent = data_sample_ids,
      vec_key_columns = "sample_name",
      name_id = "sample_id",
      name_table = "TraitsValue"
    ) |>
    prepare_table_foreign_key(
      data_parent = dplyr::select(data_traits, trait_id, trait_name),
      vec_key_columns = "trait_name",
      name_id = "trait_id",
      name_table = "TraitsValue"
    ) |>
    prepare_table_foreign_key(
      data_parent = data_taxon_ids,
      vec_key_columns = "taxon_name",
      name_id = "taxon_id",
      name_table = "TraitsValue"
    ) |>
    prepare_table_foreign_key(
      data_parent = dplyr::select(
        data_conversions,
        trait_unit_conversion_id, conversion_rule_key, standardized_unit
      ),
      vec_key_columns = "conversion_rule_key",
      name_id = "trait_unit_conversion_id",
      name_table = "TraitsValue"
    ) |>
    prepare_table_foreign_key(
      data_parent = dplyr::select(
        data_derivations,
        trait_derivation_id, derivation_rule_key, output_unit
      ),
      vec_key_columns = "derivation_rule_key",
      name_id = "trait_derivation_id",
      name_table = "TraitsValue",
      flag_allow_missing = TRUE
    )

  data_abiotic_values <-
    purrr::chuck(list_bound, "abiotic_values") |>
    prepare_table_foreign_key(
      data_parent = data_sample_ids,
      vec_key_columns = "sample_name",
      name_id = "sample_id",
      name_table = "AbioticData"
    ) |>
    prepare_table_foreign_key(
      data_parent = dplyr::select(
        data_abiotic_variables,
        abiotic_variable_id, abiotic_variable_name
      ),
      vec_key_columns = "abiotic_variable_name",
      name_id = "abiotic_variable_id",
      name_table = "AbioticData"
    ) |>
    dplyr::select(sample_id, abiotic_variable_id, abiotic_value)

  n_values_repeated <-
    data_abiotic_values |>
    dplyr::count(sample_id, abiotic_variable_id) |>
    dplyr::filter(n > 1L) |>
    base::nrow()

  if (
    n_values_repeated > 0L
  ) {
    cli::cli_abort(
      "AbioticData: {n_values_repeated} pair{?s} of sample and variable
      {?has/have} more than one value."
    )
  }

  # The unit of a value is the unit its rule produces
  data_rule_units <-
    data_trait_values |>
    dplyr::left_join(
      dplyr::select(
        data_conversions,
        trait_unit_conversion_id, standardized_unit
      ),
      by = dplyr::join_by(trait_unit_conversion_id),
      relationship = "many-to-one"
    ) |>
    dplyr::left_join(
      dplyr::select(data_derivations, trait_derivation_id, output_unit),
      by = dplyr::join_by(trait_derivation_id),
      relationship = "many-to-one"
    ) |>
    dplyr::mutate(
      rule_unit = dplyr::coalesce(output_unit, standardized_unit)
    )

  vec_unit_differs <-
    dplyr::pull(data_rule_units, rule_unit) !=
    dplyr::pull(data_rule_units, trait_unit)

  if (
    base::any(vec_unit_differs, na.rm = TRUE)
  ) {
    cli::cli_abort(
      "TraitsValue: {base::sum(vec_unit_differs, na.rm = TRUE)} value{?s}
      whose unit differs from the unit of {?its/their} rule."
    )
  }

  res <-
    base::list(
      DatasetTypeID = data_dataset_types,
      DatasetSourceTypeID = data_source_types,
      DatasetSourcesID = data_data_sources,
      SamplingMethodID = data_sampling_methods,
      References = dplyr::select(
        data_references,
        reference_id, reference_detail, mandatory
      ),
      DatasetSourceTypeReference = prepare_reference_links(
        data_links = purrr::chuck(list_bound, "source_type_references"),
        data_entity_ids = data_source_types,
        data_reference_ids = data_references,
        vec_entity_keys = "dataset_source_type",
        name_entity_id = "data_source_type_id",
        name_table = "DatasetSourceTypeReference"
      ),
      DatasetSourcesReference = prepare_reference_links(
        data_links = purrr::chuck(list_bound, "data_source_references"),
        data_entity_ids = data_data_sources,
        data_reference_ids = data_references,
        vec_entity_keys = "data_source_desc",
        name_entity_id = "data_source_id",
        name_table = "DatasetSourcesReference"
      ),
      SamplingMethodReference = prepare_reference_links(
        data_links = purrr::chuck(list_bound, "sampling_method_references"),
        data_entity_ids = data_sampling_methods,
        data_reference_ids = data_references,
        vec_entity_keys = "sampling_method_details",
        name_entity_id = "sampling_method_id",
        name_table = "SamplingMethodReference"
      ),
      Datasets = dplyr::select(
        data_datasets,
        dataset_id, dataset_name, data_source_id, dataset_type_id,
        data_source_type_id, coord_long, coord_lat, sampling_method_id
      ),
      DatasetReferences = prepare_reference_links(
        data_links = purrr::chuck(list_bound, "dataset_references"),
        data_entity_ids = data_dataset_ids,
        data_reference_ids = data_references,
        vec_entity_keys = "dataset_name",
        name_entity_id = "dataset_id",
        name_table = "DatasetReferences"
      ),
      SampleSizeID = dplyr::select(
        data_sample_sizes,
        sample_size_id, sample_size,
        description = sample_size_description
      ),
      Samples = data_samples |>
        dplyr::mutate(sample_details = NA_character_) |>
        dplyr::select(
          sample_id, sample_name, sample_details, age, sample_size_id
        ),
      SampleReference = prepare_reference_links(
        data_links = purrr::chuck(list_bound, "sample_references"),
        data_entity_ids = data_sample_ids,
        data_reference_ids = data_references,
        vec_entity_keys = "sample_name",
        name_entity_id = "sample_id",
        name_table = "SampleReference"
      ),
      DatasetSample = purrr::chuck(list_bound, "dataset_samples") |>
        prepare_table_foreign_key(
          data_parent = data_dataset_ids,
          vec_key_columns = "dataset_name",
          name_id = "dataset_id",
          name_table = "DatasetSample"
        ) |>
        prepare_table_foreign_key(
          data_parent = data_sample_ids,
          vec_key_columns = "sample_name",
          name_id = "sample_id",
          name_table = "DatasetSample"
        ) |>
        dplyr::distinct(dataset_id, sample_id) |>
        dplyr::arrange(dataset_id, sample_id),
      SampleUncertainty = purrr::chuck(list_bound, "sample_uncertainty") |>
        prepare_table_foreign_key(
          data_parent = data_sample_ids,
          vec_key_columns = "sample_name",
          name_id = "sample_id",
          name_table = "SampleUncertainty"
        ) |>
        dplyr::select(sample_id, iteration, age),
      Taxa = data_taxon_ids,
      TaxonClassification = data_taxon_classification,
      TaxonReference = prepare_reference_links(
        data_links = purrr::chuck(list_bound, "taxon_references"),
        data_entity_ids = data_taxon_ids,
        data_reference_ids = data_references,
        vec_entity_keys = "taxon_name",
        name_entity_id = "taxon_id",
        name_table = "TaxonReference"
      ),
      SampleTaxa = purrr::chuck(list_bound, "sample_taxa") |>
        prepare_table_foreign_key(
          data_parent = data_sample_ids,
          vec_key_columns = "sample_name",
          name_id = "sample_id",
          name_table = "SampleTaxa"
        ) |>
        prepare_table_foreign_key(
          data_parent = data_taxon_ids,
          vec_key_columns = "taxon_name",
          name_id = "taxon_id",
          name_table = "SampleTaxa"
        ) |>
        dplyr::select(sample_id, taxon_id, value),
      TraitsDomain = data_trait_domains |>
        dplyr::mutate(trait_domanin_description = NA_character_) |>
        dplyr::select(
          trait_domain_id, trait_domain_name, trait_unit,
          trait_domanin_description
        ),
      Traits = dplyr::select(
        data_traits,
        trait_id, trait_domain_id, trait_name
      ),
      TraitsReference = prepare_reference_links(
        data_links = purrr::chuck(list_bound, "trait_references"),
        data_entity_ids = dplyr::select(data_traits, trait_id, trait_name),
        data_reference_ids = data_references,
        vec_entity_keys = "trait_name",
        name_entity_id = "trait_id",
        name_table = "TraitsReference"
      ),
      TraitUnitConversion = data_conversions,
      TraitDerivation = data_derivations,
      TraitsValue = dplyr::select(
        data_trait_values,
        trait_id, dataset_id, sample_id, taxon_id, trait_value,
        trait_unit_conversion_id, trait_derivation_id
      ),
      AbioticVariable = dplyr::select(
        data_abiotic_variables,
        abiotic_variable_id, abiotic_variable_name, abiotic_variable_unit,
        measure_details
      ),
      AbioticVariableReference = prepare_reference_links(
        data_links = purrr::chuck(list_bound, "abiotic_variable_references"),
        data_entity_ids = dplyr::select(
          data_abiotic_variables,
          abiotic_variable_id, abiotic_variable_name
        ),
        data_reference_ids = data_references,
        vec_entity_keys = "abiotic_variable_name",
        name_entity_id = "abiotic_variable_id",
        name_table = "AbioticVariableReference"
      ),
      AbioticData = dplyr::arrange(
        data_abiotic_values,
        sample_id, abiotic_variable_id
      )
    )

  return(res)
}
