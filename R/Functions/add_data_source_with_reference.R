add_data_source_with_reference <- function(data_source, con) {
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
    add_data_source_referecne(
      data_source = data_source,
      con = con
    )

  data_source_id <-
    data_source %>%
    # TODO: find out a way to keep multiple references per data source #18
    dplyr::distinct(data_source_desc, .keep_all = TRUE) %>%
    dplyr::select(data_source_desc, data_source_reference) %>%
    tidyr::drop_na(data_source_desc) %>%
    dplyr::left_join(
      data_source_reference_db,
      by = dplyr::join_by(data_source_reference == reference_detail)
    ) %>%
    dplyr::select(
      data_source_desc, reference_id
    ) %>%
    dplyr::rename(data_source_reference = reference_id)

  data_source_desc_db <-
    dplyr::tbl(con, "DatasetSourcesID") %>%
    dplyr::distinct(data_source_desc) %>%
    dplyr::collect() %>%
    purrr::chuck("data_source_desc")

  data_source_id_unique <-
    data_source_id %>%
    dplyr::filter(
      !data_source_desc %in% data_source_desc_db
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
