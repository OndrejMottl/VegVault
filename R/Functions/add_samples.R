add_samples <- function(data_source, con) {
  assertthat::has_name(
    data_source,
    c(
      "sample_name",
      "age"
    )
  )

  samples <-
    data_source %>%
    dplyr::select(
      sample_name, age
    ) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "Samples") %>%
        dplyr::select(sample_name) %>%
        dplyr::collect(),
      by = dplyr::join_by(sample_name)
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
