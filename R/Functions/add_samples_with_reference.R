add_samples_with_reference <- function(data_source, con) {
  samples_reference_id <-
    add_sample_reference(
      data_source = data_source,
      con = con
    )

  samples <-
    data_source %>%
    dplyr::distinct(sample_name, reference_source) %>%
    dplyr::left_join(
      samples_reference_id,
      by = dplyr::join_by(reference_source == reference_detail)
    ) %>%
    dplyr::select(-reference_source) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "Samples") %>%
        dplyr::select(sample_name) %>%
        dplyr::collect(),
      by = dplyr::join_by(sample_name)
    ) %>%
    dplyr::rename(
      sample_reference = reference_id
    )

  add_to_db(
    conn = con,
    data = samples,
    table_name = "Samples"
  )

  samples_id <-
    dplyr::tbl(con, "Samples") %>%
    dplyr::select(sample_id, sample_name) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(sample_name),
      by = dplyr::join_by(sample_name)
    )

  return(samples_id)
}
