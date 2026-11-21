#' @title Prepare the tables of the sPlotOpen vegetation plots
#' @description
#' Turn the validated `splot_plots` artefact into the source tables of
#' `build_source_table_template()`: one dataset and one sample (age 0) per
#' plot, with the plot area as the sample size and the taxa with their
#' abundances, as the v1.0.0 import did.
#' @param data_splot
#' A data frame of the `splot_plots` contract: `plot_observation_id`,
#' `givd_id`, `longitude`, `latitude`, `releve_area` and the list column
#' `taxa`, whose tables hold `Species` and `Original_abundance`.
#' @param list_source
#' Named list. The `build: sources: splot` entry of `config.yml`, with
#' `dataset_type`, `dataset_source_type`, `sample_size_description` and
#' `references`.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A named list of tibbles with the elements and columns of
#' `build_source_table_template()`.
#' @details
#' Datasets and samples are both named `splot_<plot_observation_id>`, with
#' the id written by `prepare_id_text()`. The data source is the `givd_id`.
#' The source type gets the `source_type` references of `list_source`,
#' and every taxon its `taxon` references. A taxon row with an empty
#' species name is left out of the taxa and of the sample taxa (v1.0.0
#' stored such rows without a taxon); their number is reported when
#' `verbose`. Aborts when a column is missing or `list_source` lacks a
#' field.
#' @seealso [build_source_table_template()], [build_database_tables()]
#' @examples
#' \dontrun{
#' list_splot_tables <-
#'   prepare_splot_tables(
#'     data_splot = dplyr::bind_rows(data_splot_plots),
#'     list_source = load_config_value(
#'       value = c("build", "sources", "splot")
#'     )
#'   )
#' }
prepare_splot_tables <- function(
  data_splot,
  list_source,
  verbose = TRUE
) {
  vec_required <-
    c(
      "plot_observation_id", "givd_id", "longitude", "latitude",
      "releve_area", "taxa"
    )

  assertthat::assert_that(
    base::is.data.frame(data_splot),
    msg = "`data_splot` must be a data frame."
  )

  vec_absent <-
    base::setdiff(vec_required, base::names(data_splot))

  assertthat::assert_that(
    base::length(vec_absent) == 0L,
    msg = stringr::str_c(
      "`data_splot` lacks the columns: ",
      stringr::str_c(vec_absent, collapse = ", ")
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

  # Datasets and samples share the name of their plot
  data_plots <-
    data_splot |>
    dplyr::mutate(
      plot_name = stringr::str_c(
        "splot_",
        prepare_id_text(
          vec_ids = plot_observation_id,
          name_column = "plot_observation_id"
        )
      )
    )

  data_datasets <-
    tibble::tibble(
      dataset_name = dplyr::pull(data_plots, plot_name),
      dataset_type = purrr::chuck(list_source, "dataset_type"),
      dataset_source_type = purrr::chuck(list_source, "dataset_source_type"),
      data_source_desc = base::as.character(dplyr::pull(data_plots, givd_id)),
      coord_long = base::as.numeric(dplyr::pull(data_plots, longitude)),
      coord_lat = base::as.numeric(dplyr::pull(data_plots, latitude)),
      sampling_method_details = NA_character_
    )

  data_samples <-
    tibble::tibble(
      sample_name = dplyr::pull(data_plots, plot_name),
      age = 0,
      sample_size = base::as.numeric(dplyr::pull(data_plots, releve_area))
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
    dplyr::select(sample_name = plot_name, taxa) |>
    tidyr::unnest(taxa) |>
    dplyr::mutate(
      taxon_name = base::as.character(Species),
      value = base::as.numeric(Original_abundance)
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
      "sPlotOpen: left out {base::sum(vec_empty_taxon)} taxon row{?s} with
      an empty species name."
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
      "sPlotOpen: {base::nrow(data_datasets)} plot{?s} and
      {base::nrow(data_taxa)} tax{?on/a}."
    )
  }

  return(res)
}
