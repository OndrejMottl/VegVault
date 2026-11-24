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
