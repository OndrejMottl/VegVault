add_data_source_with_reference <- function(data_source, con){
  data_source_reference_db <-
    add_data_source_referecne(
      data_source = data_source,
      con = con
    )

  data_source_id <-
    data_source %>%
    dplyr::distinct(data_source_desc, data_source_reference) %>%
    tidyr::drop_na(data_source_desc) %>%
    dplyr::left_join(
      data_source_reference_db,
      by = dplyr::join_by(data_source_reference == reference_detail)
    ) %>%
    dplyr::select(
      data_source_desc, reference_id
    ) %>%
    dplyr::rename(data_source_reference = reference_id)

  data_source_id_unique <-
    data_source_id %>%
    dplyr::anti_join(
      dplyr::tbl(con, "DatasetSourcesID") %>%
        dplyr::select(data_source_desc) %>%
        dplyr::collect(),
      by = dplyr::join_by(data_source_desc)
    )

  add_to_db(
    conn = con,
    data = data_source_id_unique,
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