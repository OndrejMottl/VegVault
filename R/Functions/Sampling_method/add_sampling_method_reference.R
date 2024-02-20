add_sampling_method_reference <- function(data_source, sampling_method_id, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sampling_protocol"
      )
    ),
    msg = "data_source must have columns 'sampling_protocol'"
  )

  reference_db <-
    add_sampling_method_reference_id(
      data_source = data_source,
      con = con
    )

  sampling_method_reference <-
    data_source %>%
    dplyr::select(sampling_method_details, sampling_reference) %>%
    tidyr::unnest(sampling_reference) %>%
    dplyr::distinct(sampling_method_details, sampling_reference) %>%
    tidyr::drop_na() %>%
    dplyr::left_join(
      sampling_method_id,
      by = dplyr::join_by(sampling_method_details)
    ) %>%
    dplyr::left_join(
      reference_db,
      by = dplyr::join_by(sampling_reference == reference_detail)
    ) %>%
    dplyr::distinct(sampling_method_id, reference_id)

  sampling_method_reference_unique <-
    sampling_method_reference %>%
    dplyr::anti_join(
      dplyr::tbl(con, "SamplingMethodReference") %>%
        dplyr::collect(),
      by = dplyr::join_by(sampling_method_id, reference_id)
    )

  add_to_db(
    data = sampling_method_reference_unique,
    con = con,
    table_name = "SamplingMethodReference",
    overwrite_test = TRUE
  )
}
