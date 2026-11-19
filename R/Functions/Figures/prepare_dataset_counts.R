#' @title Prepare the dataset counts for the dataset figure
#' @description
#' Label and order the counts of `load_dataset_counts()` as the dataset
#' figure shows them.
#' @param data_dataset_counts
#' A data frame as returned by `load_dataset_counts()`, with the columns
#' `dataset_type`, `dataset_source_type` and `n_datasets`.
#' @return
#' A tibble with the same rows and columns, where `dataset_type` is a
#' factor with spaces instead of underscores, its levels ordered by the
#' number of datasets of the type (largest first), and
#' `dataset_source_type` is a factor with `FOSSILPOL` shown as
#' `Neotoma - FOSSILPOL`, its levels in the order of the rows. Rows are
#' sorted by the count of their type, then by their own count, both
#' largest first. A missing source type stays missing.
#' @details
#' Aborts when a required column is missing.
#' @examples
#' \dontrun{
#' data_dataset_counts_labelled <-
#'   prepare_dataset_counts(data_dataset_counts = data_dataset_counts)
#' }
prepare_dataset_counts <- function(data_dataset_counts) {
  validate_data_columns(
    data_source = data_dataset_counts,
    vec_columns_required = c(
      "dataset_type", "dataset_source_type", "n_datasets"
    ),
    name_argument = "data_dataset_counts"
  )

  # Types ordered by their number of datasets, source types within them
  data_counts_sorted <-
    data_dataset_counts |>
    dplyr::mutate(
      dataset_type = stringr::str_replace_all(dataset_type, "_", " "),
      dataset_source_type = dplyr::if_else(
        dataset_source_type == "FOSSILPOL",
        "Neotoma - FOSSILPOL",
        dataset_source_type
      )
    ) |>
    dplyr::group_by(dataset_type) |>
    dplyr::mutate(n_datasets_type = base::sum(n_datasets)) |>
    dplyr::ungroup() |>
    dplyr::arrange(dplyr::desc(n_datasets_type), dplyr::desc(n_datasets))

  vec_source_levels <-
    data_counts_sorted |>
    dplyr::pull(dataset_source_type) |>
    base::unique() |>
    purrr::discard(.p = base::is.na)

  res <-
    data_counts_sorted |>
    dplyr::mutate(
      dataset_type = base::factor(
        dataset_type,
        levels = base::unique(dataset_type)
      ),
      dataset_source_type = base::factor(
        dataset_source_type,
        levels = vec_source_levels
      )
    ) |>
    dplyr::select(dataset_type, dataset_source_type, n_datasets)

  return(res)
}
