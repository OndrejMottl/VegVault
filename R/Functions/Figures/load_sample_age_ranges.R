#' @title Load the sample ages of a dataset with their iteration range
#' @description
#' For one dataset, return the age of each sample and the lowest and
#' highest age among its age-model iterations (`SampleUncertainty`), for
#' the sample-age figure.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param dataset_name
#' Character scalar. The `dataset_name` of the dataset, for example
#' `fossilpol_<Neotoma dataset ID>` (`figures: sample_age: dataset_name`
#' of `config.yml`). `NULL` while no dataset is chosen.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `load_build_manifest()` and `validate_database_source()`).
#' @return
#' A tibble with one row per sample that has age iterations: `dataset_name`
#' (character), `sample_id` (integer), `age` (numeric),
#' `age_iteration_min` and `age_iteration_max` (numeric), sorted by
#' `sample_id`.
#' @details
#' Aborts when `dataset_name` is `NULL` (no dataset chosen yet), when no
#' dataset has that name, or when its samples have no age iterations. The
#' dataset is chosen by name because dataset IDs change with every build.
#' The database is opened read-only.
#' @examples
#' \dontrun{
#' data_sample_age_ranges <-
#'   load_sample_age_ranges(
#'     path_database = path_database,
#'     dataset_name = "fossilpol_1001",
#'     list_build_manifest = list_build_manifest
#'   )
#' }
load_sample_age_ranges <- function(
  path_database,
  dataset_name,
  list_build_manifest
) {
  if (
    base::is.null(dataset_name)
  ) {
    cli::cli_abort(
      c(
        "No dataset is chosen for the sample-age figure.",
        "i" = "Set {.field figures: sample_age: dataset_name} in
        {.file config.yml}."
      )
    )
  }

  assertthat::assert_that(
    base::is.character(dataset_name),
    base::length(dataset_name) == 1L,
    !base::is.na(dataset_name),
    msg = "`dataset_name` must be a character scalar."
  )

  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  sel_dataset_name <- dataset_name

  list_query <-
    run_with_database(
      path_database = path_database,
      fn = function(con) {
        data_datasets <-
          dplyr::tbl(src = con, from = "Datasets") |>
          dplyr::filter(dataset_name == !!sel_dataset_name)

        n_datasets <-
          data_datasets |>
          dplyr::count() |>
          dplyr::pull(n)

        # Each sample once, as v1 kept distinct samples and ages
        data_samples <-
          data_datasets |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "DatasetSample"),
            by = "dataset_id"
          ) |>
          dplyr::inner_join(
            dplyr::tbl(src = con, from = "Samples"),
            by = "sample_id"
          ) |>
          dplyr::distinct(dataset_name, sample_id, age)

        # Only the iterations of these samples are aggregated, not the
        #   whole table
        data_iteration_ranges <-
          dplyr::tbl(src = con, from = "SampleUncertainty") |>
          dplyr::semi_join(data_samples, by = "sample_id") |>
          dplyr::group_by(sample_id) |>
          dplyr::summarise(
            age_iteration_min = base::min(age, na.rm = TRUE),
            age_iteration_max = base::max(age, na.rm = TRUE),
            .groups = "drop"
          )

        data_ranges <-
          data_samples |>
          dplyr::inner_join(
            data_iteration_ranges,
            by = "sample_id"
          ) |>
          dplyr::select(
            dataset_name,
            sample_id,
            age,
            age_iteration_min,
            age_iteration_max
          ) |>
          dplyr::collect()

        res_query <-
          list(
            n_datasets = n_datasets,
            data_ranges = data_ranges
          )

        return(res_query)
      },
      flag_read_only = TRUE
    )

  n_datasets <-
    purrr::chuck(list_query, "n_datasets")

  if (
    n_datasets == 0L
  ) {
    cli::cli_abort(
      "No dataset named {.val {dataset_name}} in the database."
    )
  }

  if (
    n_datasets > 1L
  ) {
    cli::cli_abort(
      "{n_datasets} datasets are named {.val {dataset_name}}; the name must
      identify one dataset."
    )
  }

  data_ranges <-
    purrr::chuck(list_query, "data_ranges")

  if (
    base::nrow(data_ranges) == 0L
  ) {
    cli::cli_abort(
      "The samples of dataset {.val {dataset_name}} have no age iterations."
    )
  }

  res <-
    data_ranges |>
    dplyr::mutate(
      sample_id = base::as.integer(sample_id),
      age = base::as.numeric(age),
      age_iteration_min = base::as.numeric(age_iteration_min),
      age_iteration_max = base::as.numeric(age_iteration_max)
    ) |>
    dplyr::arrange(sample_id)

  return(res)
}
