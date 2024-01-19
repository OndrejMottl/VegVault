add_datasets <- function(
    data_source, con,
    data_type = NULL,
    data_source_type = NULL,
    dataset_source = NULL) {
  assertthat::has_name(
    data_source,
    c(
      "dataset_name",
      "coord_long",
      "coord_lat"
    )
  )

  dataset <- data_source

  if (
    isFALSE(is.null(dataset_source))
  ) {
    assertthat::has_name(dataset_source, "data_source_desc")

    dataset <-
      dataset %>%
      dplyr::left_join(
        dataset_source,
        by = dplyr::join_by(data_source_desc)
      )
  }

  if (
    isFALSE(is.null(data_type))
  ) {
    assertthat::has_name(data_type, "dataset_type")
    dataset <-
      dataset %>%
      dplyr::left_join(
        data_type,
        by = dplyr::join_by(dataset_type)
      )
  }

  if (
    isFALSE(is.null(data_source_type))
  ) {
    assertthat::has_name(data_source_type, "dataset_source_type")

    dataset <-
      dataset %>%
      dplyr::left_join(
        data_source_type,
        by = dplyr::join_by(dataset_source_type)
      )
  }

  dataset_unique <-
    dataset %>%
    dplyr::select(
      dplyr::all_of(
        c(
          "dataset_name",
          "coord_long",
          "coord_lat"
        )
      ),
      dplyr::any_of(
        c(
          "dataset_type_id",
          "data_source_type_id",
          "data_source_id"
        )
      )
    ) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "Datasets") %>%
        dplyr::select(dataset_name) %>%
        dplyr::collect(),
      by = dplyr::join_by(dataset_name)
    )

  add_to_db(
    conn = con,
    data = dataset_unique,
    table_name = "Datasets"
  )

  dataset_id <-
    dplyr::tbl(con, "Datasets") %>%
    dplyr::select(dataset_id, dataset_name) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(dataset_name),
      by = dplyr::join_by(dataset_name)
    )

  return(dataset_id)
}
