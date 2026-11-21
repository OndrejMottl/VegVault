#' @title Prepare the tables of a trait source
#' @description
#' Turn a validated trait artefact (`try_traits` or `bien_traits`) into the
#' source tables of `build_source_table_template()`: datasets by data
#' source, location and reference, one sample (age 0) per observation, the
#' taxa, the trait domains and traits, and one trait value per published
#' record, as the v1.0.0 import did.
#' @param data_traits
#' A data frame of a trait contract, with `longitude`, `latitude`,
#' `trait_domain`, `trait_full_name`, `trait_value`, `trait_unit`,
#' `conversion_rule_key`, `derivation_rule_key` and the columns named in
#' `list_columns`.
#' @param list_columns
#' Named list of the source's column names: `sample_id` (the observation
#' id), `data_source_desc` (the data source), `data_source_reference` (its
#' reference), `taxon_name` (the taxon) and `sample_references` (a
#' character vector, possibly empty, of the columns that hold sample
#' references).
#' @param name_prefix
#' Character scalar. Start of the dataset and sample names, for example
#' `"try"` or `"bien_traits"`.
#' @param list_source
#' Named list. The entry of the source in `build: sources` of
#' `config.yml`, with `dataset_type`, `dataset_source_type` and
#' `references`.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A named list of tibbles with the elements and columns of
#' `build_source_table_template()`.
#' @details
#' A dataset is one distinct combination of data source, longitude,
#' latitude and data-source reference. Datasets are sorted by these four
#' (text in the C locale, missing values last) and named
#' `<name_prefix>_<n>`, so the names follow the content rather than the
#' row order of the files (v1.0.0 numbered them in file order). Samples are
#' named `<name_prefix>_<sample_id>`, with the id written by
#' `prepare_id_text()`. Every non-missing value of the
#' `sample_references` columns is a reference of its sample, the
#' data-source reference a reference of the data source; neither is
#' mandatory. Taxa and traits get the `taxon` and `trait` references of
#' `list_source`. Every row is one trait value; none is dropped. Aborts
#' when a column is missing, when an observation belongs to more than one
#' dataset, or when a trait value is not finite.
#' @seealso [build_source_table_template()], [build_database_tables()]
#' @examples
#' \dontrun{
#' list_try_tables <-
#'   prepare_trait_tables(
#'     data_traits = dplyr::bind_rows(data_try_traits),
#'     list_columns = base::list(
#'       sample_id = "observation_id",
#'       data_source_desc = "dataset",
#'       data_source_reference = "reference_source",
#'       taxon_name = "acc_species_name",
#'       sample_references = c("dataset_reference_citation", "record_reference")
#'     ),
#'     name_prefix = "try",
#'     list_source = load_config_value(value = c("build", "sources", "try"))
#'   )
#' }
prepare_trait_tables <- function(
  data_traits,
  list_columns,
  name_prefix,
  list_source,
  verbose = TRUE
) {
  vec_column_roles <-
    c(
      "sample_id", "data_source_desc", "data_source_reference",
      "taxon_name", "sample_references"
    )

  assertthat::assert_that(
    base::is.data.frame(data_traits),
    msg = "`data_traits` must be a data frame."
  )

  assertthat::assert_that(
    base::is.list(list_columns),
    base::setequal(base::names(list_columns), vec_column_roles),
    base::all(
      purrr::map_lgl(
        .x = list_columns[vec_column_roles[1:4]],
        .f = ~ base::is.character(.x) && base::length(.x) == 1L
      )
    ),
    base::is.character(purrr::chuck(list_columns, "sample_references")),
    msg = stringr::str_c(
      "`list_columns` must name one column for each of sample_id, ",
      "data_source_desc, data_source_reference and taxon_name, and a ",
      "character vector of sample_references."
    )
  )

  assertthat::assert_that(
    base::is.character(name_prefix),
    base::length(name_prefix) == 1L,
    !base::is.na(name_prefix),
    base::nzchar(name_prefix),
    msg = "`name_prefix` must be a non-empty character scalar."
  )

  vec_required <-
    c(
      "longitude", "latitude", "trait_domain", "trait_full_name",
      "trait_value", "trait_unit", "conversion_rule_key",
      "derivation_rule_key",
      purrr::list_c(list_columns, ptype = base::character())
    )

  vec_absent <-
    base::setdiff(vec_required, base::names(data_traits))

  assertthat::assert_that(
    base::length(vec_absent) == 0L,
    msg = stringr::str_c(
      "`data_traits` lacks the columns: ",
      stringr::str_c(vec_absent, collapse = ", ")
    )
  )

  vec_absent_fields <-
    base::setdiff(
      c("dataset_type", "dataset_source_type", "references"),
      base::names(list_source)
    )

  assertthat::assert_that(
    base::is.list(list_source),
    base::length(vec_absent_fields) == 0L,
    msg = stringr::str_c(
      "`list_source` lacks the fields: ",
      stringr::str_c(vec_absent_fields, collapse = ", ")
    )
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  col_sample_id <- purrr::chuck(list_columns, "sample_id")
  col_data_source <- purrr::chuck(list_columns, "data_source_desc")
  col_reference <- purrr::chuck(list_columns, "data_source_reference")
  col_taxon <- purrr::chuck(list_columns, "taxon_name")

  vec_not_finite <-
    !base::is.finite(base::as.numeric(dplyr::pull(data_traits, trait_value)))

  if (
    base::any(vec_not_finite)
  ) {
    cli::cli_abort(
      "{name_prefix}: {base::sum(vec_not_finite)} trait value{?s} {?is/are}
      not finite."
    )
  }

  data_records <-
    data_traits |>
    dplyr::mutate(
      sample_name = stringr::str_c(
        name_prefix,
        "_",
        prepare_id_text(
          vec_ids = .data[[col_sample_id]],
          name_column = col_sample_id
        )
      ),
      data_source_desc = base::as.character(.data[[col_data_source]]),
      data_source_reference = base::as.character(.data[[col_reference]]),
      coord_long = base::as.numeric(longitude),
      coord_lat = base::as.numeric(latitude),
      taxon_name = base::as.character(.data[[col_taxon]])
    )

  # Datasets are named after their sorted content, not the file order
  data_dataset_keys <-
    data_records |>
    dplyr::distinct(
      data_source_desc, coord_long, coord_lat, data_source_reference
    ) |>
    dplyr::arrange(
      data_source_desc, coord_long, coord_lat, data_source_reference,
      .locale = "C"
    ) |>
    dplyr::mutate(
      dataset_name = stringr::str_c(name_prefix, "_", dplyr::row_number())
    )

  data_records_named <-
    dplyr::left_join(
      data_records,
      data_dataset_keys,
      by = dplyr::join_by(
        data_source_desc, coord_long, coord_lat, data_source_reference
      ),
      relationship = "many-to-one",
      na_matches = "na"
    )

  data_dataset_samples <-
    dplyr::distinct(data_records_named, dataset_name, sample_name)

  vec_repeated_samples <-
    data_dataset_samples |>
    dplyr::count(sample_name) |>
    dplyr::filter(n > 1L) |>
    dplyr::pull(sample_name)

  if (
    base::length(vec_repeated_samples) > 0L
  ) {
    cli::cli_abort(
      c(
        "{name_prefix}: {base::length(vec_repeated_samples)} observation{?s}
        belong{?s/} to more than one dataset.",
        "x" = "First: {.val {utils::head(vec_repeated_samples, 5L)}}."
      )
    )
  }

  data_datasets <-
    data_dataset_keys |>
    dplyr::mutate(
      dataset_type = purrr::chuck(list_source, "dataset_type"),
      dataset_source_type = purrr::chuck(list_source, "dataset_source_type"),
      sampling_method_details = NA_character_
    )

  data_data_sources <-
    data_datasets |>
    dplyr::filter(!base::is.na(data_source_desc)) |>
    dplyr::distinct(data_source_desc)

  data_source_references <-
    dplyr::bind_rows(
      dplyr::cross_join(
        data_data_sources,
        prepare_config_references(
          list_source = list_source,
          sel_role = "data_source"
        )
      ),
      data_datasets |>
        dplyr::filter(
          !base::is.na(data_source_desc),
          !base::is.na(data_source_reference)
        ) |>
        dplyr::mutate(
          reference_detail = data_source_reference,
          mandatory = FALSE
        ) |>
        dplyr::select(data_source_desc, reference_detail, mandatory)
    ) |>
    dplyr::summarise(
      mandatory = base::any(mandatory),
      .by = c(data_source_desc, reference_detail)
    )

  data_samples <-
    data_dataset_samples |>
    dplyr::distinct(sample_name) |>
    dplyr::mutate(
      age = 0,
      sample_size = NA_real_,
      sample_size_description = NA_character_
    )

  data_sample_references <-
    purrr::chuck(list_columns, "sample_references") |>
    purrr::map(
      .f = ~ data_records_named |>
        dplyr::mutate(reference_detail = base::as.character(.data[[.x]])) |>
        dplyr::filter(!base::is.na(reference_detail)) |>
        dplyr::select(sample_name, reference_detail)
    ) |>
    purrr::list_rbind() |>
    dplyr::bind_rows(
      tibble::tibble(
        sample_name = base::character(0),
        reference_detail = base::character(0)
      )
    ) |>
    dplyr::distinct(sample_name, reference_detail) |>
    dplyr::mutate(mandatory = FALSE)

  data_taxa <-
    data_records_named |>
    dplyr::distinct(taxon_name) |>
    dplyr::arrange(taxon_name, .locale = "C")

  data_traits_named <-
    data_records_named |>
    dplyr::distinct(
      trait_name = trait_full_name,
      trait_domain_name = trait_domain
    )

  list_tables <-
    base::list(
      datasets = dplyr::select(
        data_datasets,
        dataset_name, dataset_type, dataset_source_type, data_source_desc,
        coord_long, coord_lat, sampling_method_details
      ),
      source_type_references = dplyr::cross_join(
        tibble::tibble(
          dataset_source_type = purrr::chuck(list_source, "dataset_source_type")
        ),
        prepare_config_references(
          list_source = list_source,
          sel_role = "source_type"
        )
      ),
      data_source_references = data_source_references,
      samples = data_samples,
      sample_references = data_sample_references,
      dataset_samples = data_dataset_samples,
      taxa = data_taxa,
      taxon_references = dplyr::cross_join(
        data_taxa,
        prepare_config_references(list_source = list_source, sel_role = "taxon")
      ),
      trait_domains = dplyr::distinct(
        data_records_named,
        trait_domain_name = trait_domain,
        trait_unit
      ),
      traits = data_traits_named,
      trait_references = dplyr::cross_join(
        dplyr::distinct(data_traits_named, trait_name),
        prepare_config_references(list_source = list_source, sel_role = "trait")
      ),
      trait_values = data_records_named |>
        dplyr::mutate(
          trait_name = trait_full_name,
          trait_value = base::as.numeric(trait_value)
        ) |>
        dplyr::select(
          dataset_name, sample_name, trait_name, taxon_name, trait_value,
          trait_unit, conversion_rule_key, derivation_rule_key
        )
    )

  # Every element of the template, with its columns and types
  res <-
    build_source_table_template() |>
    purrr::imap(
      .f = ~ dplyr::bind_rows(.x, purrr::pluck(list_tables, .y))
    )

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform(
      "{name_prefix}: {base::nrow(data_datasets)} dataset{?s},
      {base::nrow(data_samples)} sample{?s} and
      {base::nrow(data_records_named)} trait value{?s}."
    )
  }

  return(res)
}
