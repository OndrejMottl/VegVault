add_samples_with_reference <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source, c(
        "sample_name",
        "age",
        "reference_source"
      )
    ),
    msg = "data_source must have a column named sample_name, age, and reference_source"
  )

  samples_reference_id <-
    add_sample_reference(
      data_source = data_source,
      con = con
    )

  sample_db <-
    dplyr::tbl(con, "Samples") %>%
    dplyr::distinct(sample_name) %>%
    dplyr::collect() %>%
    purrr::chuck("sample_name")

  samples <-
    data_source %>%
    dplyr::distinct(sample_name, age, reference_source) %>%
    dplyr::left_join(
      samples_reference_id,
      by = dplyr::join_by(reference_source == reference_detail)
    ) %>%
    dplyr::select(-reference_source) %>%
    dplyr::filter(
      !sample_name %in% sample_db
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
