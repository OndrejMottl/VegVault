#' @title Prepare the tables of the FOSSILPOL fossil-pollen archives
#' @description
#' Turn the validated `fossilpol_assembly` and `fossilpol_age_uncertainty`
#' artefacts into the source tables of `build_source_table_template()`: one
#' dataset per archive, one sample per level with counts, the harmonised
#' pollen counts as sample taxa and the age-model iterations as sample
#' uncertainty, as the v1.0.0 import did.
#' @param data_assembly
#' A data frame of the `fossilpol_assembly` contract: `dataset_id`,
#' `source_of_data`, `doi`, `long`, `lat`, `depositionalenvironment` and
#' the list columns `levels` (tables with `sample_id` and `age`) and
#' `counts_harmonised` (tables with `sample_id` and one count column per
#' taxon).
#' @param data_age_uncertainty
#' A data frame of the `fossilpol_age_uncertainty` contract: `dataset_id`
#' and the list column `age_uncertainty`, whose matrices have one row per
#' iteration and one column per level, named by the level `sample_id`.
#' @param list_source
#' Named list. The `build: sources: fossilpol` entry of `config.yml`, with
#' `dataset_type`, `dataset_source_type` and `references`.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A named list of tibbles with the elements and columns of
#' `build_source_table_template()`.
#' @details
#' Datasets are named `fossilpol_<dataset_id>` and samples
#' `fossilpol_<dataset_id>_<sample_id>`, from the Neotoma ids. (v1.0.0 put
#' the database id of the dataset into sample names, so they changed with
#' every build.) The data source is the `source_of_data`, with the
#' `data_source` references of `list_source`; the sampling method is the
#' `depositionalenvironment`, with its `sampling_method` references; the
#' `doi` is the dataset reference.
#' Only levels that have counts become samples, as in v1.0.0; their ages
#' are kept as they are. The taxa are the count columns of every archive
#' (never other columns: v1.0.0 also stored four column names as taxa), and
#' a sample taxon is kept only when its count is above zero. Iterations of
#' a level that is not a sample are left out and counted when `verbose`.
#' The iteration is the row number of the matrix. Aborts when a column is
#' missing, when a matrix has no column names, or when `list_source` lacks
#' a field.
#' @seealso [build_source_table_template()], [build_database_tables()]
#' @examples
#' \dontrun{
#' list_fossilpol_tables <-
#'   prepare_fossilpol_tables(
#'     data_assembly = dplyr::bind_rows(data_fossilpol_assembly),
#'     data_age_uncertainty = dplyr::bind_rows(
#'       data_fossilpol_age_uncertainty
#'     ),
#'     list_source = load_config_value(
#'       value = c("build", "sources", "fossilpol")
#'     )
#'   )
#' }
prepare_fossilpol_tables <- function(
  data_assembly,
  data_age_uncertainty,
  list_source,
  verbose = TRUE
) {
  vec_required <-
    c(
      "dataset_id", "source_of_data", "doi", "long", "lat",
      "depositionalenvironment", "levels", "counts_harmonised"
    )

  assertthat::assert_that(
    base::is.data.frame(data_assembly),
    msg = "`data_assembly` must be a data frame."
  )

  vec_absent <-
    base::setdiff(vec_required, base::names(data_assembly))

  assertthat::assert_that(
    base::length(vec_absent) == 0L,
    msg = stringr::str_c(
      "`data_assembly` lacks the columns: ",
      stringr::str_c(vec_absent, collapse = ", ")
    )
  )

  vec_absent_uncertainty <-
    base::setdiff(
      c("dataset_id", "age_uncertainty"),
      base::names(data_age_uncertainty)
    )

  assertthat::assert_that(
    base::is.data.frame(data_age_uncertainty),
    base::length(vec_absent_uncertainty) == 0L,
    msg = stringr::str_c(
      "`data_age_uncertainty` lacks the columns: ",
      stringr::str_c(vec_absent_uncertainty, collapse = ", ")
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

  data_archives <-
    data_assembly |>
    dplyr::mutate(
      dataset_name = stringr::str_c(
        "fossilpol_",
        prepare_id_text(vec_ids = dataset_id, name_column = "dataset_id")
      )
    )

  data_datasets <-
    tibble::tibble(
      dataset_name = dplyr::pull(data_archives, dataset_name),
      dataset_type = purrr::chuck(list_source, "dataset_type"),
      dataset_source_type = purrr::chuck(list_source, "dataset_source_type"),
      data_source_desc = base::as.character(
        dplyr::pull(data_archives, source_of_data)
      ),
      coord_long = base::as.numeric(dplyr::pull(data_archives, long)),
      coord_lat = base::as.numeric(dplyr::pull(data_archives, lat)),
      sampling_method_details = base::as.character(
        dplyr::pull(data_archives, depositionalenvironment)
      )
    )

  # Levels become samples only when they have counts, as in v1.0.0
  data_levels <-
    data_archives |>
    dplyr::mutate(
      levels_counted = purrr::map2(
        .x = levels,
        .y = counts_harmonised,
        .f = ~ dplyr::semi_join(
          dplyr::select(.x, sample_id, age),
          .y,
          by = dplyr::join_by(sample_id)
        ) |>
          dplyr::mutate(sample_id = base::as.character(sample_id))
      )
    ) |>
    dplyr::select(dataset_name, levels_counted) |>
    tidyr::unnest(levels_counted) |>
    dplyr::mutate(
      sample_name = stringr::str_c(
        dataset_name,
        "_",
        prepare_id_text(vec_ids = sample_id, name_column = "sample_id")
      )
    )

  data_samples <-
    tibble::tibble(
      sample_name = dplyr::pull(data_levels, sample_name),
      age = base::as.numeric(dplyr::pull(data_levels, age)),
      sample_size = NA_real_,
      sample_size_description = NA_character_
    )

  # Counts in long form, one row per level and taxon above zero
  data_counts_long <-
    data_archives |>
    dplyr::mutate(
      counts_long = purrr::map(
        .x = counts_harmonised,
        .f = ~ tidyr::pivot_longer(
          dplyr::mutate(
            .x,
            sample_id = base::as.character(sample_id),
            dplyr::across(.cols = !sample_id, .fns = base::as.numeric)
          ),
          cols = !sample_id,
          names_to = "taxon_name",
          values_to = "value"
        )
      )
    ) |>
    dplyr::select(dataset_name, counts_long) |>
    tidyr::unnest(counts_long) |>
    dplyr::mutate(
      sample_name = stringr::str_c(
        dataset_name,
        "_",
        prepare_id_text(vec_ids = sample_id, name_column = "sample_id")
      )
    )

  data_sample_taxa <-
    data_counts_long |>
    dplyr::filter(
      value > 0,
      sample_name %in% dplyr::pull(data_samples, sample_name)
    ) |>
    dplyr::select(sample_name, taxon_name, value)

  # The taxa are the count columns of every archive, never other columns
  data_taxa <-
    tibble::tibble(
      taxon_name = dplyr::pull(data_archives, counts_harmonised) |>
        purrr::map(.f = base::names) |>
        purrr::list_c(ptype = base::character()) |>
        base::setdiff("sample_id")
    ) |>
    dplyr::arrange(taxon_name, .locale = "C")

  vec_named_matrix <-
    purrr::map_lgl(
      .x = dplyr::pull(data_age_uncertainty, age_uncertainty),
      .f = ~ base::is.matrix(.x) && !base::is.null(base::colnames(.x))
    )

  if (
    !base::all(vec_named_matrix)
  ) {
    cli::cli_abort(
      "{base::sum(!vec_named_matrix)} age-uncertainty entr{?y/ies} {?is/are}
      not a matrix with column names (the level ids)."
    )
  }

  # Matrices are read column by column: one column per level
  data_uncertainty_all <-
    data_age_uncertainty |>
    dplyr::mutate(
      dataset_name = stringr::str_c(
        "fossilpol_",
        prepare_id_text(vec_ids = dataset_id, name_column = "dataset_id")
      ),
      uncertainty_long = purrr::map(
        .x = age_uncertainty,
        .f = ~ tibble::tibble(
          iteration = base::rep(
            base::seq_len(base::nrow(.x)),
            times = base::ncol(.x)
          ),
          sample_id = base::rep(base::colnames(.x), each = base::nrow(.x)),
          age = base::as.numeric(.x)
        )
      )
    ) |>
    dplyr::select(dataset_name, uncertainty_long) |>
    tidyr::unnest(uncertainty_long) |>
    dplyr::mutate(
      sample_name = stringr::str_c(dataset_name, "_", sample_id)
    )

  vec_uncertainty_kept <-
    dplyr::pull(data_uncertainty_all, sample_name) %in%
    dplyr::pull(data_samples, sample_name)

  if (
    base::isTRUE(verbose) &&
      !base::all(vec_uncertainty_kept)
  ) {
    cli::cli_inform(
      "FOSSILPOL: left out {base::sum(!vec_uncertainty_kept)} age iteration
      row{?s} of levels that have no counts."
    )
  }

  data_uncertainty <-
    data_uncertainty_all |>
    dplyr::filter(vec_uncertainty_kept) |>
    dplyr::select(sample_name, iteration, age)

  data_dataset_references <-
    data_archives |>
    dplyr::filter(!base::is.na(doi)) |>
    dplyr::mutate(
      reference_detail = base::as.character(doi),
      mandatory = FALSE
    ) |>
    dplyr::select(dataset_name, reference_detail, mandatory)

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
      sampling_method_references = dplyr::cross_join(
        dplyr::distinct(
          dplyr::filter(data_datasets, !base::is.na(sampling_method_details)),
          sampling_method_details
        ),
        prepare_config_references(
          list_source = list_source,
          sel_role = "sampling_method"
        )
      ),
      dataset_references = data_dataset_references,
      samples = data_samples,
      dataset_samples = dplyr::select(data_levels, dataset_name, sample_name),
      sample_uncertainty = data_uncertainty,
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
      "FOSSILPOL: {base::nrow(data_datasets)} archive{?s},
      {base::nrow(data_samples)} level{?s} with counts and
      {base::nrow(data_taxa)} tax{?on/a}."
    )
  }

  return(res)
}
