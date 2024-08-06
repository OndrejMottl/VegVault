add_chelsa_neo_data <- function(
    sel_con,
    sel_url,
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
    dowload_and_load(sel_url) %>%
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
      coord_long = as.numeric(.data$long),
      coord_lat = as.numeric(.data$lat),
      age = 0
    ) %>%
    dplyr::mutate(
      dataset_name = paste(
        "geo",
        round(.data$coord_long, digits = 2),
        round(.data$coord_lat, digits = 2),
        sep = "_"
      )
    ) %>%
    tidyr::nest(
      data_samples = c(
        "age",
        "value"
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
      abiotic_variable_name = sel_var_name,
      var_unit = sel_var_unit,
      var_reference = sel_var_reference,
      var_detail = sel_var_detail
    )

  data_samples_db <-
    dplyr::tbl(sel_con, "Samples") %>%
    dplyr::distinct(.data$sample_id, .data$sample_name) %>%
    dplyr::collect()

  data_climate_sub <-
    data_climate_raw %>%
    dplyr::filter(
      .data$sample_name %in% data_samples_db$sample_name
    )

  # Abiotic varibale
  abiotic_variabe_id <-
    add_abiotic_variable(
      data_source = data_climate_sub,
      con = sel_con
    )

  add_sample_abiotic_value(
    data_source = data_climate_sub,
    con = sel_con,
    sample_id = data_samples_db,
    abiotic_variable_id = abiotic_variabe_id
  )
}
