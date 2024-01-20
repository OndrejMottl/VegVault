add_dataset_sample_name <- function(data_source, dataset_id, con, sel_name = NULL) {
  assertthat::has_name(
    data_source,
    c(
      "dataset_name",
      "sample_id"
    )
  )

  assertthat::has_name(
    dataset_id,
    c(
      "dataset_name",
      "dataset_id"
    )
  )

  data_source %>%
    dplyr::left_join(
      dataset_id,
      by = dplyr::join_by(dataset_name)
    ) %>%
    dplyr::mutate(
      sample_name = paste0(
        sel_name,
        dataset_id,
        "_",
        sample_id
      )
    ) %>%
    dplyr::select(-sample_id) %>%
    return()
}
