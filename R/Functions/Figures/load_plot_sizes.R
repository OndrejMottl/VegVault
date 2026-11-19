#' @title Load the plot sizes of vegetation plot samples
#' @description
#' Return the plot size of every sample of the vegetation plot datasets,
#' for the plot-size figure.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' A tibble with one row per sample: `sample_id` (integer), `sample_size`
#' (numeric) and `sample_size_unit` (character, the `description` of
#' `SampleSizeID`), sorted by `sample_id`. Samples without a size have
#' `NA` in both size columns.
#' @details
#' The database is opened read-only.
#' @examples
#' \dontrun{
#' data_plot_sizes <-
#'   load_plot_sizes(
#'     path_database = path_database,
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_plot_sizes <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  data_plot_sizes_raw <-
    run_with_database(
      path_database = path_database,
      fn = function(con) {
        res_sizes <-
          dplyr::tbl(src = con, from = "Datasets") |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "DatasetTypeID"),
            by = "dataset_type_id"
          ) |>
          dplyr::filter(dataset_type == "vegetation_plot") |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "DatasetSample"),
            by = "dataset_id"
          ) |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "Samples"),
            by = "sample_id"
          ) |>
          dplyr::left_join(
            dplyr::tbl(src = con, from = "SampleSizeID"),
            by = "sample_size_id"
          ) |>
          dplyr::select(
            sample_id,
            sample_size,
            sample_size_unit = description
          ) |>
          dplyr::distinct() |>
          dplyr::collect()

        return(res_sizes)
      },
      flag_read_only = TRUE
    )

  res <-
    data_plot_sizes_raw |>
    dplyr::mutate(
      sample_id = base::as.integer(sample_id),
      sample_size = base::as.numeric(sample_size),
      sample_size_unit = base::as.character(sample_size_unit)
    ) |>
    dplyr::arrange(sample_id)

  return(res)
}
