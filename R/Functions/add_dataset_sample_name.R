add_dataset_sample_name <- function(data_source, dataset_id, con, sel_name = NULL) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "dataset_name",
        "sample_id"
      )
    ),
    msg = "data_source must have columns 'dataset_name' and 'sample_id'"
  )

  assertthat::assert_that(
    assertthat::has_name(
      dataset_id,
      c(
        "dataset_name",
        "dataset_id"
      )
    ),
    msg = "dataset_id must have columns 'dataset_name' and 'dataset_id'"
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
