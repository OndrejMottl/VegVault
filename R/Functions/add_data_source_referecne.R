add_data_source_referecne <- function(data_source, con) {

assertthat::assert_that(
  assertthat::has_name(data_source, "data_source_reference"),
  msg = "data_source must have a column named data_source_reference"
)

  data_source_reference <-
    data_source %>%
    dplyr::distinct(data_source_reference) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "References") %>%
        dplyr::collect(),
      by = dplyr::join_by(data_source_reference == reference_detail)
    ) %>%
    dplyr::rename(reference_detail = data_source_reference)

  add_to_db(
    conn = con,
    data = data_source_reference,
    table_name = "References"
  )

  data_source_reference_db <-
    dplyr::tbl(con, "References") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(data_source_reference),
      by = dplyr::join_by(reference_detail == data_source_reference)
    )

  return(data_source_reference_db)
}
