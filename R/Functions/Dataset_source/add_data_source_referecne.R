add_data_source_referecne <- function(data_source, data_source_id, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source, c(
        "data_source_desc",
        "data_source_reference"
      )
    ),
    msg = "data_source must have a column named data_source_desc and data_source_reference"
  )

  data_source_reference_db <-
    add_data_source_referecne_id(
      data_source = data_source,
      con = con
    )

  data_source_reference_lookup <-
    data_source %>%
    dplyr::distinct(data_source_desc, data_source_reference) %>%
    tidyr::drop_na() %>%
    dplyr::left_join(
      data_source_reference_db,
      by = dplyr::join_by(data_source_reference == reference_detail)
    ) %>%
    dplyr::left_join(
      data_source_id,
      by = dplyr::join_by(data_source_desc)
    ) %>%
    dplyr::select(
      data_source_id, reference_id
    )

  data_source_reference_unique <-
    data_source_reference_lookup %>%
    dplyr::anti_join(
      dplyr::tbl(con, "DatasetSourcesReference") %>%
        dplyr::collect(),
      by = dplyr::join_by(data_source_id, reference_id)
    )

  add_to_db(
    conn = con,
    data = data_source_reference_unique,
    table_name = "DatasetSourcesReference",
    overwrite_test = TRUE
  )
}
