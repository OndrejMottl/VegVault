# Build the validation database (helper-build_validation_database.R) and
#   replace its abiotic data: the variables of `data_variables`, and one
#   gridpoint dataset per distinct (long, lat) of `data_values` with one
#   sample per age, holding the values of `data_values` (columns `long`,
#   `lat`, `age`, `variable` and `value`). Dataset and sample ids start at
#   100. Returns the list of build_validation_database().
build_abiotic_validation_database <- function(
  dir,
  data_values,
  data_variables = tibble::tribble(
    ~abiotic_variable_id, ~abiotic_variable_name, ~abiotic_variable_unit,
    ~measure_details,
    1L, "bio1", "C (degree Celsius)", "mean annual air temperature",
    2L, "bio12", "kg m-2 year-1", "annual precipitation amount"
  )
) {
  list_build <-
    build_validation_database(dir = dir)

  data_cells <-
    data_values |>
    dplyr::distinct(long, lat) |>
    dplyr::mutate(dataset_id = 99L + dplyr::row_number())

  data_samples <-
    data_values |>
    dplyr::distinct(long, lat, age) |>
    dplyr::left_join(data_cells, by = dplyr::join_by(long, lat)) |>
    dplyr::mutate(sample_id = 99L + dplyr::row_number())

  data_abiotic <-
    data_values |>
    dplyr::left_join(data_samples, by = dplyr::join_by(long, lat, age)) |>
    dplyr::left_join(
      data_variables,
      by = dplyr::join_by(variable == abiotic_variable_name)
    ) |>
    dplyr::select(sample_id, abiotic_variable_id, abiotic_value = value)

  run_with_database(
    path_database = purrr::chuck(list_build, "path_database"),
    fn = ~ {
      DBI::dbExecute(.x, "DELETE FROM AbioticData")
      DBI::dbExecute(.x, "DELETE FROM AbioticVariable")
      DBI::dbAppendTable(.x, "AbioticVariable", data_variables)
      DBI::dbAppendTable(
        .x,
        "Datasets",
        dplyr::transmute(
          data_cells,
          dataset_id,
          dataset_name = stringr::str_c("gridpoint_test_", dataset_id),
          dataset_type_id = 4L,
          data_source_type_id = 5L,
          coord_long = long,
          coord_lat = lat
        )
      )
      DBI::dbAppendTable(
        .x,
        "Samples",
        dplyr::transmute(
          data_samples,
          sample_id,
          sample_name = stringr::str_c("grid_test_", sample_id),
          age
        )
      )
      DBI::dbAppendTable(
        .x,
        "DatasetSample",
        dplyr::select(data_samples, dataset_id, sample_id)
      )
      DBI::dbAppendTable(.x, "AbioticData", data_abiotic)
    }
  )

  return(list_build)
}

# Value rules in the format of build_abiotic_value_rules(), small enough to
#   check by hand: bio1 at age 0 and at 500 to 18000 years, bio4 with an
#   excluded lower bound and bio12 at age 0, bio18 with a forbidden value,
#   and a soil code
build_abiotic_test_rules <- function() {
  res <-
    tibble::tribble(
      ~artefact_id, ~variable, ~unit, ~details, ~age_min, ~age_max,
      ~range_min, ~range_max, ~flag_min_inclusive, ~flag_max_inclusive,
      ~list_forbidden, ~list_allowed, ~flag_whole_number,
      "chelsa_neoclimate", "bio1", "C (degree Celsius)",
      "mean annual air temperature", 0, 0, -80, 45, TRUE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "chelsa_neoclimate", "bio4", "C/100 (hundredths of a degree Celsius)",
      "temperature seasonality", 0, 0, 0, 3000, FALSE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "chelsa_neoclimate", "bio12", "kg m-2 year-1",
      "annual precipitation amount", 0, 0, 0, 15000, TRUE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "chelsa_neoclimate", "bio18", "kg m-2 quarter-1",
      "precipitation amount of the warmest quarter", 0, 0, 0, 12000,
      TRUE, TRUE, list(6553.5), list(numeric(0)), FALSE,
      "chelsa_trace21k_palaeoclimate", "bio1", "C (degree Celsius)",
      "mean annual air temperature", 500, 18000, -80, 45, TRUE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "chelsa_trace21k_palaeoclimate", "bio12", "kg m-2 year-1",
      "annual precipitation amount", 500, 18000, 0, 15000, TRUE, TRUE,
      list(numeric(0)), list(numeric(0)), FALSE,
      "hwsd_soil", "HWSD2", "Unitless", NA_character_, -Inf, Inf,
      -Inf, Inf, TRUE, TRUE, list(numeric(0)), list(as.numeric(1:32)), TRUE
    ) |>
    dplyr::mutate(
      list_forbidden = purrr::map(list_forbidden, unlist),
      list_allowed = purrr::map(list_allowed, unlist)
    )

  return(res)
}
