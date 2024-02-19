add_samples <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sample_name",
        "age"
      )
    ),
    msg = "data_source must have columns 'sample_name' and 'age'"
  )

  samples_db <-
    dplyr::tbl(con, "Samples") %>%
    dplyr::distinct(sample_name) %>%
    dplyr::collect() %>%
    purrr::chuck("sample_name")

  samples <-
    data_source %>%
    dplyr::select(
      sample_name, age
    ) %>%
    dplyr::filter(
      !sample_name %in% samples_db
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
