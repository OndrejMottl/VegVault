add_chelsa_neo_data <- function(
    sel_url,
    sel_var_name,
    sel_var_unit,
    sel_var_reference,
    sel_var_detail,
    sel_grid_size_degree = 2,
    sel_distance_km = 50,
    sel_distance_years = 5e3) {
  current_env <- environment()

  # download and load ---
  data_climate <-
    dowload_and_load(sel_url) %>%
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
      age = 0
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

  data_bd_vegetation <-
    vaultkeepr::open_vault(
      path = paste0(
        data_storage_path,
        "Data/VegVault/VegVault.sqlite"
      )
    ) %>%
    vaultkeepr::get_datasets() %>%
    vaultkeepr::select_dataset_by_type(
      sel_dataset_type = c("vegetation_plot", "fossil_pollen_archive", "traits")
    ) %>%
    vaultkeepr::select_dataset_by_geo(
      sel_dataset_type = c("vegetation_plot", "fossil_pollen_archive", "traits"),
      long_lim = c(-180, 180),
      lat_lim = c(-90, 90)
    ) %>%
    vaultkeepr::get_samples() %>%
    vaultkeepr::select_samples_by_age(
      sel_dataset_type = c("vegetation_plot", "fossil_pollen_archive", "traits"),
      # just very large number to get rid of NAs
      age_lim = c(-1e10, 1e10)
    ) %>%
    vaultkeepr::extract_data() %>%
    dplyr::distinct(dataset_id, sample_name, coord_long, coord_lat, age)


  data_climate_samples_to_limit <-
    data_climate_dataset_raw %>%
    dplyr::left_join(
      climate_dataset_id_db,
      by = dplyr::join_by(dataset_name)
    ) %>%
    dplyr::select(
      dataset_id, coord_long, coord_lat
    ) %>%
    dplyr::left_join(
      data_climate_samples_raw,
      by = "dataset_id"
    ) %>%
    dplyr::distinct(dataset_id, sample_name, coord_long, coord_lat, age)

  data_sample_link <-
    data_bd_vegetation %>%
    dplyr::mutate(
      batch = 1 + (dplyr::row_number() - 1) %/% 5000
    ) %>%
    dplyr::group_by(batch) %>%
    tidyr::nest(data = -batch) %>%
    dplyr::ungroup() %>%
    purrr::chuck("data") %>%
    rlang::set_names(paste0("batch_", 1:length(.))) %>%
    purrr::imap(
      .progress = "filtering gripoints samples",
      .f = ~ {
        message(.y)
        get_gridpoints_link(
          data_source = .x,
          data_source_gridpoints = data_climate_samples_to_limit,
          sel_grid_size_degree = sel_grid_size_degree,
          sel_distance_km = sel_distance_km,
          sel_distance_years = sel_distance_years
        ) %>%
          return()
      }
    ) %>%
    dplyr::bind_rows()

  vec_sample_name_to_keep <-
    data_sample_link %>%
    dplyr::distinct(sample_name_gridpoints) %>%
    dplyr::arrange(sample_name_gridpoints) %>%
    dplyr::pull(sample_name_gridpoints)

  data_climate_samples_filter <-
    data_climate_samples_raw %>%
    dplyr::filter(sample_name %in% vec_sample_name_to_keep)

  climate_samples_id_db <-
    add_samples(
      data_source = data_climate_samples_raw,
      con = con
    )

  # Dataset - Sample -----
  add_dataset_sample(
    data_source = data_climate_samples_filter,
    con = con,
    dataset_id = climate_dataset_id_db,
    sample_id = climate_samples_id_db
  )

  # Abiotic sample reference
  add_abiotic_data_ref(
    data_source = data_sample_link,
    con = con
  )

  # Abiotic varibale
  abiotic_variabe_id <-
    add_abiotic_variable(
      data_source = data_climate_samples_filter,
      con = con
    )

  add_sample_abiotic_value(
    data_source = data_climate_samples_filter,
    con = con,
    sample_id = climate_samples_id_db,
    abiotic_variable_id = abiotic_variabe_id
  )
}
