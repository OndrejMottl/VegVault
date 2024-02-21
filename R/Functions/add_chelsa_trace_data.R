add_chelsa_trace_data <- function(
    sel_url,
    sel_hash,
    sel_var_name,
    sel_var_unit,
    sel_var_reference,
    sel_var_detail) {
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
  data_climate_dataset_raw <-
    data_climate %>%
    dplyr::mutate(
      dataset_type = "gridpoints",
      dataset_source_type = "gridpoints",
      data_source_type_reference = "artificially created by O. Mottl",
      data_source_desc = "gridpoints",
      data_source_reference = "artificially created by O. Mottl",
      dataset_reference = "artificially created by O. Mottl",
      coord_long = as.numeric(long),
      coord_lat = as.numeric(lat),
      age = (-as.numeric(time_id) * 100) + 2000
    ) %>%
    dplyr::select(-time_id) %>%
    tidyr::nest(
      data_samples = c(
        age,
        value
      )
    ) %>%
    dplyr::mutate(
      dataset_name = paste(
        "geo", round(coord_long, digits = 2), round(coord_lat, digits = 2),
        sep = "_"
      )
    )

  # dataset type -----
  data_climate_dataset_type_db <-
    add_dataset_type(
      data_source = data_climate_dataset_raw,
      con = con
    )

  # dataset source type -----
  data_climate_dataset_source_type_db <-
    add_dataset_source_type(
      data_source = data_climate_dataset_raw,
      con = con
    )

  # dataset source -----
  data_climate_data_source_id_db <-
    add_data_source(
      data_source = data_climate_dataset_raw,
      con = con
    )

  # datasets -----
  climate_dataset_id_db <-
    add_datasets(
      data_source = data_climate_dataset_raw,
      con = con,
      data_type = data_climate_dataset_type_db,
      data_source_type = data_climate_dataset_source_type_db,
      dataset_source = data_climate_data_source_id_db
    )

  # samples -----
  data_climate_samples_raw <-
    data_climate_dataset_raw %>%
    dplyr::left_join(
      climate_dataset_id_db,
      by = dplyr::join_by(dataset_name)
    ) %>%
    dplyr::select(
      dataset_name, dataset_id, data_samples,
    ) %>%
    tidyr::unnest(data_samples) %>%
    dplyr::mutate(
      sample_name = paste0(
        "geo_",
        dataset_id,
        "_",
        age
      ),
      sample_size = NA_real_,
      description = "gridpoint",
      sample_reference = "artificially created by O. Mottl",
      abiotic_variable_name = sel_var_name,
      var_unit = sel_var_unit,
      var_reference = sel_var_reference,
      var_detail = sel_var_detail
    )

  climate_samples_id_db <-
    add_samples(
      data_source = data_climate_samples_raw,
      con = con
    )

  # Dataset - Sample -----
  add_dataset_sample(
    data_source = data_climate_samples_raw,
    con = con,
    dataset_id = climate_dataset_id_db,
    sample_id = climate_samples_id_db
  )

  # Abiotic varibale
  abiotic_variabe_id <-
    add_abiotic_variable(
      data_source = data_climate_samples_raw,
      con = con
    )

  add_sample_abiotic_value(
    data_source = data_climate_samples_raw,
    con = con,
    sample_id = climate_samples_id_db,
    abiotic_variable_id = abiotic_variabe_id
  )
}
