#' @title Prepare the tables of the gridpoints
#' @description
#' Turn the linked gridpoints into the source tables of
#' `build_source_table_template()`: one dataset per grid cell and one
#' sample per cell and age, with the gridpoint references, as the v1.0.0
#' gridpoint stage did.
#' @param data_gridpoints
#' A data frame with `coord_long`, `coord_lat`, `age`, `dataset_name` and
#' `sample_name`, one row per gridpoint (see `prepare_position_tables()`).
#' @param list_source
#' Named list. The `build: sources: gridpoints` entry of `config.yml`, with
#' `dataset_type`, `dataset_source_type`, `data_source_desc` and
#' `references`.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A named list of tibbles with the elements and columns of
#' `build_source_table_template()`.
#' @details
#' The names come from the gridpoint stage (`geo_<long>_<lat>` and
#' `geo_<long>_<lat>_<age>`). The datasets have the rounded cell
#' coordinates and no sampling method; the samples have no sample size.
#' The source type gets the `source_type` references of `list_source`, the
#' data source its `data_source` references, every dataset its `dataset`
#' references and every sample its `sample` references, as in v1.0.0.
#' Aborts when a column is missing, when a dataset name has two pairs of
#' coordinates, or when `list_source` lacks a field.
#' @seealso [prepare_position_tables()], [build_database_tables()]
#' @examples
#' \dontrun{
#' list_gridpoint_tables <-
#'   prepare_gridpoint_tables(
#'     data_gridpoints = purrr::chuck(list_positions, "gridpoints"),
#'     list_source = load_config_value(
#'       value = c("build", "sources", "gridpoints")
#'     )
#'   )
#' }
prepare_gridpoint_tables <- function(
  data_gridpoints,
  list_source,
  verbose = TRUE
) {
  vec_required <-
    c("coord_long", "coord_lat", "age", "dataset_name", "sample_name")

  vec_absent <-
    base::setdiff(vec_required, base::names(data_gridpoints))

  assertthat::assert_that(
    base::is.data.frame(data_gridpoints),
    base::length(vec_absent) == 0L,
    msg = stringr::str_c(
      "`data_gridpoints` lacks the columns: ",
      stringr::str_c(vec_absent, collapse = ", ")
    )
  )

  vec_absent_fields <-
    base::setdiff(
      c(
        "dataset_type", "dataset_source_type", "data_source_desc",
        "references"
      ),
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

  data_cells <-
    data_gridpoints |>
    dplyr::distinct(dataset_name, coord_long, coord_lat) |>
    dplyr::arrange(dataset_name, .locale = "C")

  vec_moving <-
    data_cells |>
    dplyr::count(dataset_name) |>
    dplyr::filter(n > 1L) |>
    dplyr::pull(dataset_name)

  if (
    base::length(vec_moving) > 0L
  ) {
    cli::cli_abort(
      "{base::length(vec_moving)} gridpoint dataset{?s} with more than one
      pair of coordinates: {.val {utils::head(vec_moving, 5L)}}."
    )
  }

  name_data_source <-
    purrr::chuck(list_source, "data_source_desc")

  data_datasets <-
    data_cells |>
    dplyr::mutate(
      dataset_type = purrr::chuck(list_source, "dataset_type"),
      dataset_source_type = purrr::chuck(list_source, "dataset_source_type"),
      data_source_desc = name_data_source,
      coord_long = base::as.numeric(coord_long),
      coord_lat = base::as.numeric(coord_lat),
      sampling_method_details = NA_character_
    )

  data_samples <-
    data_gridpoints |>
    dplyr::distinct(sample_name, age) |>
    dplyr::mutate(
      age = base::as.numeric(age),
      sample_size = NA_real_,
      sample_size_description = NA_character_
    )

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
        tibble::tibble(data_source_desc = name_data_source),
        prepare_config_references(
          list_source = list_source,
          sel_role = "data_source"
        )
      ),
      dataset_references = dplyr::cross_join(
        dplyr::select(data_datasets, dataset_name),
        prepare_config_references(
          list_source = list_source,
          sel_role = "dataset"
        )
      ),
      samples = data_samples,
      sample_references = dplyr::cross_join(
        dplyr::select(data_samples, sample_name),
        prepare_config_references(
          list_source = list_source,
          sel_role = "sample"
        )
      ),
      dataset_samples = dplyr::distinct(
        data_gridpoints,
        dataset_name, sample_name
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
      "Gridpoints: {base::nrow(data_datasets)} cell{?s} and
      {base::nrow(data_samples)} sample{?s}."
    )
  }

  return(res)
}
