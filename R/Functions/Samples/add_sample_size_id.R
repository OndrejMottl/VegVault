add_sample_size_id <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sample_size",
        "description"
      )
    ),
    msg = "data_source must have columns 'sample_size' and 'description'"
  )

  sample_size <-
    data_source %>%
    dplyr::distinct(sample_size, description) %>%
    tidyr::drop_na() %>%
    dplyr::arrange(sample_size)

  samples_size_unique <-
    sample_size %>%
    dplyr::anti_join(
      dplyr::tbl(con, "SampleSizeID") %>%
        dplyr::collect(),
      by = dplyr::join_by(sample_size, description)
    )

  add_to_db(
    conn = con,
    data = samples_size_unique,
    table_name = "SampleSizeID"
  )

  sample_size_id_db <-
    dplyr::tbl(con, "SampleSizeID") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(sample_size, description) %>%
        tidyr::drop_na(),
      by = dplyr::join_by(sample_size, description)
    ) %>%
    dplyr::select(sample_size_id, sample_size, description)

  return(sample_size_id_db)
}
