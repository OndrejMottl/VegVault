add_dataset_source_type_reference <- function(
    data_source,
    data_source_type_id,
    con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "data_source_type_reference"),
    msg = "data_source must have a column named data_source_type_reference"
  )

  dataset_reference_detail_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::distinct(reference_detail) %>%
    dplyr::collect() %>%
    purrr::pluck("reference_detail")

  dataset_source_type_referecne <-
    data_source %>%
    dplyr::select(data_source_type_reference) %>%
    tidyr::unnest(data_source_type_reference) %>%
    dplyr::distinct(data_source_type_reference) %>%
    dplyr::filter(
      !data_source_type_reference %in% dataset_reference_detail_db
    ) %>%
    dplyr::rename(reference_detail = data_source_type_reference)

  add_to_db(
    conn = con,
    data = dataset_source_type_referecne,
    table_name = "References"
  )

  dataset_source_type_referecne_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::select(data_source_type_reference) %>%
        tidyr::unnest(data_source_type_reference) %>%
        dplyr::distinct(data_source_type_reference),
      by = dplyr::join_by(reference_detail == data_source_type_reference)
    )

  dataset_source_type_referecne_lookup <-
    data_source %>%
    dplyr::select(dataset_source_type, data_source_type_reference) %>%
    tidyr::unnest(data_source_type_reference) %>%
    dplyr::distinct(dataset_source_type, data_source_type_reference) %>%
    dplyr::left_join(
      dataset_source_type_referecne_db,
      by = dplyr::join_by(data_source_type_reference == reference_detail)
    ) %>%
    dplyr::left_join(
      data_source_type_id,
      by = dplyr::join_by(dataset_source_type)
    ) %>%
    dplyr::distinct(
      data_source_type_id,
      reference_id
    )

  dataset_source_type_referecne_lookup_unique <-
    dataset_source_type_referecne_lookup %>%
    dplyr::anti_join(
      dplyr::tbl(con, "DatasetSourceTypeReference") %>%
        dplyr::collect(),
      by = dplyr::join_by(
        data_source_type_id,
        reference_id
      )
    )

  add_to_db(
    conn = con,
    data = dataset_source_type_referecne_lookup_unique,
    table_name = "DatasetSourceTypeReference",
    overwrite_test = TRUE
  )
}
