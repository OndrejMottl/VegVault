add_samples_id <- function(data_source, samples_size_id, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sample_name",
        "age",
        "sample_size",
        "description"
      )
    ),
    msg = "data_source must have columns 'sample_name', 'age', 'sample_size', and 'description'"
  )

  samples_db <-
    dplyr::tbl(con, "Samples") %>%
    dplyr::distinct(sample_name) %>%
    dplyr::collect() %>%
    purrr::chuck("sample_name")

  samples <-
    data_source %>%
    dplyr::distinct(
      sample_name, age, sample_size, description
    ) %>%
    tidyr::drop_na(sample_name, age) %>%
    dplyr::left_join(
      samples_size_id,
      by = dplyr::join_by(sample_size, description)
    )  %>% 
    dplyr::select(-sample_size, -description) 

  samples_unique <-
    samples %>%
    dplyr::filter(
      !sample_name %in% samples_db
    )

  add_to_db(
    conn = con,
    data = samples_unique,
    table_name = "Samples"
  )

  samples_id <-
    dplyr::tbl(con, "Samples") %>%
    dplyr::select(sample_id, sample_name) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      samples %>%
        dplyr::distinct(sample_name),
      by = dplyr::join_by(sample_name)
    )

  return(samples_id)
}
