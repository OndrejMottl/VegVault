add_chelsa_trace_data <- function(
    sel_con,
    sel_url,
    sel_hash,
    sel_var_name,
    sel_var_unit,
    sel_var_reference,
    sel_var_detail,
    sel_grid_size_degree = 2,
    sel_distance_km = 50,
    sel_distance_years = 5e3) {
  `%>%` <- magrittr::`%>%`
  .data <- rlang::.data
  current_env <- environment()

  # download and load ---
  data_climate <-
    sel_hash %>%
    purrr::map(
      .f = ~ paste0(
        sel_url,
        .x
      ) %>%
        dowload_and_load()
    ) %>%
    dplyr::bind_rows() %>%
    dplyr::mutate(
      var_name = sel_var_name
    )

  assertthat::assert_that(
    exists("data_climate", envir = current_env),
    msg = "data_climate not found"
  )

  # Datasets -----
  data_climate_raw <-
    data_climate %>%
    dplyr::mutate(
      dataset_type = "gridpoints",
      dataset_source_type = "gridpoints",
      data_source_type_reference = "artificially created by O. Mottl",
      data_source_desc = "gridpoints",
      data_source_reference = "artificially created by O. Mottl",
      dataset_reference = "artificially created by O. Mottl",
      coord_long = as.numeric(.data$long),
      coord_lat = as.numeric(.data$lat),
      age = (-as.numeric(.data$time_id) * 100) + 1950
    ) %>%
    dplyr::select(-"time_id") %>%
    # we do not want to use the 0 age
    #   as it would get confused with modern values
    dplyr::filter(.data$age > 0) %>%
    tidyr::nest(
      data_samples = c(
        .data$age,
        .data$value
      )
    ) %>%
    dplyr::mutate(
      dataset_name = paste(
        "geo",
        round(.data$coord_long, digits = 2),
        round(.data$coord_lat, digits = 2),
        sep = "_"
      )
    ) %>%
    tidyr::unnest("data_samples") %>%
    dplyr::mutate(
      sample_name = paste0(
        .data$dataset_name,
        "_",
        .data$age
      ),
      sample_size = NA_real_,
      description = "gridpoint",
      sample_reference = "artificially created by O. Mottl",
      abiotic_variable_name = sel_var_name,
      var_unit = sel_var_unit,
      var_reference = sel_var_reference,
      var_detail = sel_var_detail
    )

  # dataset type -----
  data_climate_dataset_type_db <-
    add_dataset_type(
      data_source = data_climate_raw,
      con = sel_con
    )

  # dataset source type -----
  data_climate_dataset_source_type_db <-
    add_dataset_source_type(
      data_source = data_climate_raw,
      con = sel_con
    )

  # dataset source -----
  data_climate_data_source_id_db <-
    add_data_source(
      data_source = data_climate_raw,
      con = sel_con
    )

  add_gridpoints_with_links(
    data_source = data_climate_raw,
    sel_con = sel_con,
    dataset_type_db = data_climate_dataset_type_db,
    dataset_source_type_db = data_climate_dataset_source_type_db,
    data_source_id_db = data_climate_data_source_id_db,
    sel_grid_size_degree = sel_grid_size_degree,
    sel_distance_km = sel_distance_km,
    sel_distance_years = sel_distance_years
  )

  climate_samples_id_db <-
    dplyr::tbl(sel_con, "Samples") %>%
    dplyr::select(.data$sample_id, .data$sample_name) %>%
    dplyr::distinct(.data$sample_id, .data$sample_name)

  # Abiotic varibale
  abiotic_variabe_id <-
    add_abiotic_variable(
      data_source = data_climate_raw,
      con = sel_con
    )

  add_sample_abiotic_value(
    data_source = data_climate_raw,
    con = sel_con,
    sample_id = climate_samples_id_db,
    abiotic_variable_id = abiotic_variabe_id
  )
}
