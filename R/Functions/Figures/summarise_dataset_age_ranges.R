#' @title Summarise the age range of fossil pollen datasets
#' @description
#' Reduce the fossil pollen rows of `load_trait_example()` to the youngest,
#' mean and oldest sample age of each dataset.
#' @param data_trait_example_raw
#' A data frame as returned by `load_trait_example()`, with at least
#' `dataset_type`, `dataset_id`, `sample_id` and `age`.
#' @return
#' A tibble with one row per fossil pollen dataset: `dataset_id`,
#' `age_min`, `age_mean` and `age_max` (numeric, over the distinct samples),
#' sorted by `dataset_id`.
#' @details
#' Aborts when a required column is missing.
#' @examples
#' \dontrun{
#' data_dataset_age_ranges <-
#'   summarise_dataset_age_ranges(
#'     data_trait_example_raw = data_trait_example_raw
#'   )
#' }
summarise_dataset_age_ranges <- function(data_trait_example_raw) {
  validate_data_columns(
    data_source = data_trait_example_raw,
    vec_columns_required = c("dataset_type", "dataset_id", "sample_id", "age"),
    name_argument = "data_trait_example_raw"
  )

  res <-
    data_trait_example_raw |>
    dplyr::filter(dataset_type == "fossil_pollen_archive") |>
    dplyr::distinct(dataset_id, sample_id, age) |>
    dplyr::group_by(dataset_id) |>
    dplyr::summarise(
      age_min = base::min(age),
      age_mean = base::mean(age),
      age_max = base::max(age),
      .groups = "drop"
    ) |>
    dplyr::arrange(dataset_id)

  return(res)
}
