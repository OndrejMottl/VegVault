add_samples_with_size <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sample_name",
        "age",
        "sample_size"
      )
    ),
    msg = "data_source must have columns 'sample_name', 'age' and 'sample_size'"
  )

  sample_size_id_db <-
    add_sample_size(
      data_source = data_source,
      con = con
    )

  samples <-
    data_source %>%
    dplyr::left_join(
      sample_size_id_db,
      by = dplyr::join_by(sample_size)
    ) %>%
    dplyr::select(
      sample_name, age, sample_size_id
    ) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "Samples") %>%
        dplyr::collect(),
      by = dplyr::join_by(sample_name)
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
