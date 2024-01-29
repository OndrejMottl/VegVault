add_sampling_method <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "sampling_method_details"),
    msg = "data_source must have column 'sampling_method_details'"
  )

  sampling_method <-
    data_source %>%
    dplyr::distinct(sampling_method_details) %>%
    tidyr::drop_na() %>%
    dplyr::anti_join(
      dplyr::tbl(con, "SamplingMethodID") %>%
        dplyr::select(sampling_method_details) %>%
        dplyr::collect(),
      by = dplyr::join_by(sampling_method_details)
    )

  add_to_db(
    conn = con,
    data = sampling_method,
    table_name = "SamplingMethodID"
  )

  sampling_method_db <-
    dplyr::tbl(con, "SamplingMethodID") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(sampling_method_details),
      by = dplyr::join_by(sampling_method_details)
    )

  return(sampling_method_db)
}
