add_sampling_reference <- function(data_source, con) {
  assertthat::has_name(data_source, "sampling_reference")

  sampling_method_reference <-
    data_source %>%
    dplyr::distinct(sampling_reference) %>%
    tidyr::drop_na() %>%
    dplyr::rename(
      reference_detail = sampling_reference
    ) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "References") %>%
        dplyr::select(-reference_id) %>%
        dplyr::collect(),
      by = dplyr::join_by(reference_detail)
    )

  add_to_db(
    conn = con,
    data = sampling_method_reference,
    table_name = "References"
  )

  reference_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(sampling_reference),
      by = dplyr::join_by(reference_detail == sampling_reference)
    )

  return(reference_db)
}
