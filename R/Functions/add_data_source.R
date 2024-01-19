add_data_source <- function(data_source, con) {
  assertthat::has_name(data_source, "data_source_desc")

  data_source_id <-
    data_source %>%
    dplyr::distinct(data_source_desc) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "DatasetSourcesID") %>%
        dplyr::collect(),
      by = dplyr::join_by(data_source_desc)
    )

  add_to_db(
    conn = con,
    data = data_source_id,
    table_name = "DatasetSourcesID"
  )

  data_source_id_db <-
    dplyr::tbl(con, "DatasetSourcesID") %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(data_source_desc),
      by = dplyr::join_by(data_source_desc)
    )

    return(data_source_id_db)
}
