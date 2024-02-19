add_sampling_method_with_reference <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sampling_protocol",
        "sampling_reference"
      )
    ),
    msg = "data_source must have columns 'sampling_protocol' and 'sampling_reference'"
  )

  reference_db <-
    add_sampling_reference(
      data_source = data_source,
      con = con
    )

  sampling_method <-
    data_source %>%
    dplyr::left_join(
      reference_db,
      by = dplyr::join_by(sampling_reference == reference_detail)
    ) %>%
    dplyr::distinct(sampling_protocol, reference_id) %>%
    tidyr::drop_na(sampling_protocol) %>%
    dplyr::rename(
      sampling_method_details = sampling_protocol,
      sampling_method_reference = reference_id
    )

  sampling_method_id_db <-
    dplyr::tbl(con, "SamplingMethodID") %>%
    dplyr::distinct(sampling_method_details) %>%
    dplyr::collect() %>%
    purrr::chuck("sampling_method_details")

  sampling_method_unique <-
    sampling_method %>%
    dplyr::filter(
      !sampling_method_details %in% sampling_method_id_db
    )

  add_to_db(
    conn = con,
    data = sampling_method_unique,
    table_name = "SamplingMethodID"
  )

  sampling_method_db <-
    dplyr::tbl(con, "SamplingMethodID") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      sampling_method,
      by = dplyr::join_by(sampling_method_details, sampling_method_reference)
    )

  return(sampling_method_db)
}
