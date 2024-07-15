add_abiotic_data_ref <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "sample_name",
        "sample_name_gridpoints"
      )
    ),
    msg = "data_source must have columns 'sample_name' and 'sample_name_gridpoints'"
  )

  assertthat::assert_that(
    assertthat::has_name(sample_id, "sample_id"),
    msg = "sample_id must have column 'sample_id'"
  )

  sample_id_db <-
    dplyr::tbl(con, "Samples") %>%
    dplyr::select(sample_id, sample_name) %>%
    dplyr::collect()

  dataset_sample <-
    data_source %>%
    dplyr::select(
      sample_name, sample_name_gridpoints, distance_in_km, distance_in_years
    ) %>%
    dplyr::left_join(
      sample_id_db,
      by = dplyr::join_by(sample_name)
    ) %>%
    dplyr::left_join(
      sample_id_db,
      by = dplyr::join_by("sample_name_gridpoints" == "sample_name"),
      suffix = c("", "_gridpoints")
    ) %>%
    dplyr::select(,
      sample_id,
      sample_ref_id = sample_id_gridpoints,
      distance_in_km,
      distance_in_years
    ) %>%
    dplyr::mutate(
      distance_in_km = as.integer(distance_in_km),
      distance_in_years = as.integer(distance_in_years)
    )

  dataset_sample_unique <-
    dataset_sample %>%
    dplyr::anti_join(
      dplyr::tbl(con, "AbioticDataReference") %>%
        dplyr::select(sample_id, sample_ref_id) %>%
        dplyr::collect(),
      by = dplyr::join_by(sample_id, sample_ref_id)
    )

  add_to_db(
    conn = con,
    data = dataset_sample_unique,
    table_name = "AbioticDataReference",
    overwrite_test = TRUE
  )
}
