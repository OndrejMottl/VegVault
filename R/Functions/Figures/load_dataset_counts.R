#' @title Load the number of datasets per type and source type
#' @description
#' Count the datasets of the database by dataset type and dataset source
#' type, for the dataset figure.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' A tibble with the columns `dataset_type` and `dataset_source_type`
#' (character, as stored in the database) and `n_datasets` (integer), one
#' row per combination that has datasets, sorted by type and source type.
#' Datasets without a source type are counted with `dataset_source_type`
#' `NA`, last within their type.
#' @details
#' Datasets whose type is missing from the lookup table are not counted,
#' as in v1. v1 counted the datasets per type (the waffle) with or without
#' a source type, and per source type (the lollipops) only with one; the
#' `NA` rows keep both counts possible. The database is opened read-only.
#' @examples
#' \dontrun{
#' data_dataset_counts <-
#'   load_dataset_counts(
#'     path_database = path_database,
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_dataset_counts <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  data_counts_raw <-
    run_with_database(
      path_database = path_database,
      fn = function(con) {
        res_counts <-
          dplyr::tbl(src = con, from = "Datasets") |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "DatasetTypeID"),
            by = "dataset_type_id"
          ) |>
          dplyr::left_join(
            dplyr::tbl(src = con, from = "DatasetSourceTypeID"),
            by = "data_source_type_id"
          ) |>
          dplyr::count(
            dataset_type,
            dataset_source_type,
            name = "n_datasets"
          ) |>
          dplyr::collect()

        return(res_counts)
      },
      flag_read_only = TRUE
    )

  # dplyr sorts in the C locale, the same on every machine
  res <-
    data_counts_raw |>
    dplyr::mutate(n_datasets = base::as.integer(n_datasets)) |>
    dplyr::arrange(dataset_type, dataset_source_type)

  return(res)
}
