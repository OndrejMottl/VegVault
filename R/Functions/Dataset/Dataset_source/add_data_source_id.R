add_data_source_id <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "data_source_desc"),
    msg = "data_source must have column 'data_source_desc'"
  )

  data_source_desc_db <-
    dplyr::tbl(con, "DatasetSourcesID") %>%
    dplyr::distinct(data_source_desc) %>%
    dplyr::collect() %>%
    purrr::chuck("data_source_desc")

  data_source_id <-
    data_source %>%
    dplyr::distinct(data_source_desc) %>%
    dplyr::filter(
      !data_source_desc %in% data_source_desc_db
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
