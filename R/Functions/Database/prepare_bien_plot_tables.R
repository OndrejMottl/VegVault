#' @title Prepare the tables of the BIEN vegetation plots
#' @description
#' Turn the validated `bien_plots` artefact into the source tables of
#' `build_source_table_template()`: one dataset and one sample (age 0) per
#' plot, with its sampling method, the plot area as the sample size and
#' the taxa with their individual counts, as the v1.0.0 import did.
#' @param data_bien
#' A data frame of the `bien_plots` contract with the stable plot key
#' `plot_id`: `plot_id`, `datasource`, `longitude`, `latitude`,
#' `methodology_reference`, `methodology_description`, `plot_area_ha` and
#' the list column `plot_data`, whose tables hold `name_matched` and
#' `individual_count`.
#' @param list_source
#' Named list. The `build: sources: bien_plots` entry of `config.yml`, with
#' `dataset_type`, `dataset_source_type`, `sample_size_description` and
#' `references`.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A named list of tibbles with the elements and columns of
#' `build_source_table_template()`.
#' @details
#' Datasets and samples are both named `bien_<plot_id>` (v1.0.0 used the
#' row number of the producer file, which changes when rows are added or
#' reordered). The data source is the `datasource`, the sampling method the
#' `methodology_description`; each sampling method gets the
#' `sampling_method` references of `list_source` and the
#' `methodology_reference` of its plots. The sample size is
#' `plot_area_ha * 10000` square metres; a plot without an area has no
#' sample size. Taxon rows with an empty name are left out and counted
#' when `verbose`. Aborts when a column is missing or `list_source` lacks
#' a field.
#' @seealso [build_source_table_template()], [build_database_tables()]
#' @examples
#' \dontrun{
#' list_bien_tables <-
#'   prepare_bien_plot_tables(
#'     data_bien = dplyr::bind_rows(data_bien_plots),
#'     list_source = load_config_value(
#'       value = c("build", "sources", "bien_plots")
#'     )
#'   )
#' }
prepare_bien_plot_tables <- function(
  data_bien,
  list_source,
  verbose = TRUE
) {
  vec_required <-
    c(
      "plot_id", "datasource", "longitude", "latitude",
      "methodology_reference", "methodology_description", "plot_area_ha",
      "plot_data"
    )

  assertthat::assert_that(
    base::is.data.frame(data_bien),
    msg = "`data_bien` must be a data frame."
  )

  vec_absent <-
    base::setdiff(vec_required, base::names(data_bien))

  assertthat::assert_that(
    base::length(vec_absent) == 0L,
    msg = stringr::str_c(
      "`data_bien` lacks the columns: ",
      stringr::str_c(vec_absent, collapse = ", "),
      " (BIEN plots are named after the stable `plot_id`)"
    )
  )

  vec_fields <-
    c(
      "dataset_type", "dataset_source_type", "sample_size_description",
      "references"
    )

  vec_absent_fields <-
    base::setdiff(vec_fields, base::names(list_source))

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

  data_plots <-
    data_bien |>
    dplyr::mutate(
      plot_name = stringr::str_c(
        "bien_",
        prepare_id_text(vec_ids = plot_id, name_column = "plot_id")
      ),
      sampling_method_details = base::as.character(methodology_description)
    )

  data_datasets <-
    tibble::tibble(
      dataset_name = dplyr::pull(data_plots, plot_name),
      dataset_type = purrr::chuck(list_source, "dataset_type"),
      dataset_source_type = purrr::chuck(list_source, "dataset_source_type"),
      data_source_desc = base::as.character(
        dplyr::pull(data_plots, datasource)
      ),
      coord_long = base::as.numeric(dplyr::pull(data_plots, longitude)),
      coord_lat = base::as.numeric(dplyr::pull(data_plots, latitude)),
      sampling_method_details = dplyr::pull(
        data_plots,
        sampling_method_details
      )
    )

  data_methods <-
    data_plots |>
    dplyr::filter(!base::is.na(sampling_method_details)) |>
    dplyr::distinct(sampling_method_details)

  # Each sampling method: the fixed references and those of its plots
  data_method_references <-
    dplyr::bind_rows(
      dplyr::cross_join(
        data_methods,
        prepare_config_references(
          list_source = list_source,
          sel_role = "sampling_method"
        )
      ),
      data_plots |>
        dplyr::filter(
          !base::is.na(sampling_method_details),
          !base::is.na(methodology_reference)
        ) |>
        dplyr::mutate(
          reference_detail = base::as.character(methodology_reference),
          mandatory = FALSE
        ) |>
        dplyr::select(sampling_method_details, reference_detail, mandatory)
    ) |>
    dplyr::summarise(
      mandatory = base::any(mandatory),
      .by = c(sampling_method_details, reference_detail)
    )

  data_samples <-
    tibble::tibble(
      sample_name = dplyr::pull(data_plots, plot_name),
      age = 0,
      sample_size = base::as.numeric(dplyr::pull(data_plots, plot_area_ha)) *
        10000
    ) |>
    dplyr::mutate(
      sample_size_description = dplyr::if_else(
        base::is.na(sample_size),
        NA_character_,
        purrr::chuck(list_source, "sample_size_description")
      )
    )

  data_sample_taxa_all <-
    data_plots |>
    dplyr::select(sample_name = plot_name, plot_data) |>
    tidyr::unnest(plot_data) |>
    dplyr::mutate(
      taxon_name = base::as.character(name_matched),
      value = base::as.numeric(individual_count)
    ) |>
    dplyr::select(sample_name, taxon_name, value)

  vec_empty_taxon <-
    base::is.na(dplyr::pull(data_sample_taxa_all, taxon_name)) |
    dplyr::pull(data_sample_taxa_all, taxon_name) == ""

  if (
    base::isTRUE(verbose) &&
      base::any(vec_empty_taxon)
  ) {
    cli::cli_inform(
      "BIEN plots: left out {base::sum(vec_empty_taxon)} taxon row{?s} with
      an empty name."
    )
  }

  data_sample_taxa <-
    dplyr::filter(data_sample_taxa_all, !vec_empty_taxon)

  data_taxa <-
    data_sample_taxa |>
    dplyr::distinct(taxon_name) |>
    dplyr::arrange(taxon_name, .locale = "C")

  list_tables <-
    base::list(
      datasets = data_datasets,
      source_type_references = dplyr::cross_join(
        tibble::tibble(
          dataset_source_type = purrr::chuck(list_source, "dataset_source_type")
        ),
        prepare_config_references(
          list_source = list_source,
          sel_role = "source_type"
        )
      ),
      data_source_references = dplyr::cross_join(
        dplyr::distinct(
          dplyr::filter(data_datasets, !base::is.na(data_source_desc)),
          data_source_desc
        ),
        prepare_config_references(
          list_source = list_source,
          sel_role = "data_source"
        )
      ),
      sampling_method_references = data_method_references,
      samples = data_samples,
      dataset_samples = tibble::tibble(
        dataset_name = dplyr::pull(data_plots, plot_name),
        sample_name = dplyr::pull(data_plots, plot_name)
      ),
      taxa = data_taxa,
      taxon_references = dplyr::cross_join(
        data_taxa,
        prepare_config_references(list_source = list_source, sel_role = "taxon")
      ),
      sample_taxa = data_sample_taxa
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
      "BIEN plots: {base::nrow(data_datasets)} plot{?s} and
      {base::nrow(data_taxa)} tax{?on/a}."
    )
  }

  return(res)
}
