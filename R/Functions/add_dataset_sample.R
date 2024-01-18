add_dataset_sample <- function(data_source, dataset_id, sample_id, con) {
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
