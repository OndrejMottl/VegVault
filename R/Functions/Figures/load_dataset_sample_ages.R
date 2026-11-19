#' @title Load the locations and sample ages of datasets
#' @description
#' Return the distinct combinations of dataset, location and sample age
#' for the datasets of the given types, for the sample-coverage figure.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param vec_dataset_types
#' Character vector of dataset types as stored in the database, for
#' example `c("vegetation_plot", "fossil_pollen_archive")`.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' A tibble with the distinct rows of `dataset_id` (integer),
#' `dataset_type` (character), `coord_long`, `coord_lat` and `age`
#' (numeric) over all samples of those datasets, sorted by `dataset_id` and
#' `age`.
#' @details
#' Datasets without samples are left out. v1 extracted every sample with
#' `vaultkeepr` and reduced the rows afterwards; the database does the
#' reduction here, with the same result. The database is opened read-only.
#' @examples
#' \dontrun{
#' data_dataset_sample_ages <-
#'   load_dataset_sample_ages(
#'     path_database = path_database,
#'     vec_dataset_types = c("vegetation_plot", "fossil_pollen_archive"),
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_dataset_sample_ages <- function(
  path_database,
  vec_dataset_types,
  list_build_manifest
) {
  assertthat::assert_that(
    base::is.character(vec_dataset_types),
    base::length(vec_dataset_types) > 0L,
    !base::anyNA(vec_dataset_types),
    msg = "`vec_dataset_types` must be a non-empty character vector."
  )

  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  data_sample_ages_raw <-
    run_with_database(
      path_database = path_database,
      fn = function(con) {
        res_ages <-
          dplyr::tbl(src = con, from = "Datasets") |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "DatasetTypeID"),
            by = "dataset_type_id"
          ) |>
          dplyr::filter(dataset_type %in% !!vec_dataset_types) |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "DatasetSample"),
            by = "dataset_id"
          ) |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "Samples"),
            by = "sample_id"
          ) |>
          dplyr::distinct(
            dataset_id,
            dataset_type,
            coord_long,
            coord_lat,
            age
          ) |>
          dplyr::collect()

        return(res_ages)
      },
      flag_read_only = TRUE
    )

  res <-
    data_sample_ages_raw |>
    dplyr::mutate(
      dataset_id = base::as.integer(dataset_id),
      coord_long = base::as.numeric(coord_long),
      coord_lat = base::as.numeric(coord_lat),
      age = base::as.numeric(age)
    ) |>
    dplyr::arrange(dataset_id, age)

  return(res)
}
