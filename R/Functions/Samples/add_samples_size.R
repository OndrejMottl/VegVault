add_samples_size <- function(data_source, samples_size_id, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sample_name",
        "sample_size",
        "description"
      )
    ),
    msg = "data_source must have columns 'sample_name','sample_size', and 'description'"
  )

  samples_id_db <-
    dplyr::tbl(con, "Samples") %>%
    dplyr::distinct(sample_name, sample_id) %>%
    dplyr::collect()

  samples_size_lookup <-
    data_source %>%
    dplyr::distinct(sample_name, sample_size, description) %>%
    tidyr::drop_na() %>%
    dplyr::left_join(
      samples_size_id,
      by = dplyr::join_by(sample_size, description)
    ) %>%
    dplyr::left_join(
      samples_id_db,
      by = dplyr::join_by(sample_name)
    )  %>% 
    dplyr::distinct(sample_id, sample_size_id)

  samples_size_unique <-
    samples_size_lookup %>% 
    dplyr::anti_join(
      dplyr::tbl(con, "SampleSize") %>%
        dplyr::collect(),
      by = dplyr::join_by(sample_id, sample_size_id)
    )

  add_to_db(
    conn = con,
    samples,
    table_name = "Samples"
  )

  samples_id_db <-
    dplyr::tbl(con, "Samples") %>%
    dplyr::select(sample_id, sample_name) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(sample_name),
      by = dplyr::join_by(sample_name)
    )

  return(samples_id_db)
}
