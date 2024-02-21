add_dataset_sample <- function(data_source, dataset_id, sample_id, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "dataset_name",
        "sample_name"
      )
    ),
    msg = "data_source must have columns 'dataset_name' and 'sample_name'"
  )

  assertthat::assert_that(
    assertthat::has_name(dataset_id, "dataset_id"),
    msg = "dataset_id must have column 'dataset_id'"
  )

  assertthat::assert_that(
    assertthat::has_name(sample_id, "sample_id"),
    msg = "sample_id must have column 'sample_id'"
  )

  dataset_sample <-
    data_source %>%
    dplyr::distinct(
      dataset_name, sample_name
    ) %>%
    dplyr::left_join(
      dataset_id,
      by = dplyr::join_by(dataset_name)
    ) %>%
    dplyr::left_join(
      sample_id,
      by = dplyr::join_by(sample_name)
    ) %>%
    dplyr::distinct(
      dataset_id, sample_id
    )

  dataset_sample_unique <-
    dataset_sample %>%
    dplyr::anti_join(
      dplyr::tbl(con, "DatasetSample") %>%
        dplyr::select(dataset_id, sample_id) %>%
        dplyr::collect(),
      by = dplyr::join_by(dataset_id, sample_id)
    )

  add_to_db(
    conn = con,
    data = dataset_sample_unique,
    table_name = "DatasetSample",
    overwrite_test = TRUE
  )
}
