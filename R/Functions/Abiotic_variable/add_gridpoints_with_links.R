add_gridpoints_with_links <- function(
    data_source,
    sel_con,
    dataset_type_db,
    dataset_source_type_db,
    data_source_id_db,
    sel_grid_size_degree = 2,
    sel_distance_km = 50,
    sel_distance_years = 5e3) {
  `%>%` <- magrittr::`%>%`
  .data <- rlang::.data
  current_env <- environment()

  data_gridpoints_raw <-
    data_source %>%
    dplyr::select(
      "dataset_name",
      "sample_name",
      "coord_long",
      "coord_lat",
      "age"
    )

  data_bd_vegetation_raw <-
    dplyr::tbl(sel_con, "Datasets") %>%
    dplyr::filter(
      .data$dataset_type_id != 4
    ) %>%
    dplyr::inner_join(
      dplyr::tbl(sel_con, "DatasetSample"),
      by = dplyr::join_by("dataset_id")
    ) %>%
    dplyr::left_join(
      dplyr::tbl(sel_con, "Samples") %>%
        dplyr::select("sample_id", "sample_name", "age"),
      by = dplyr::join_by("sample_id")
    ) %>%
    dplyr::select(
      "dataset_name",
      "sample_name",
      "coord_long", "coord_lat",
      "age"
    ) %>%
    dplyr::distinct() %>%
    dplyr::collect()

  gc(verbose = FALSE)

  # check if there are any previous data about links

  vec_gridpoints_sample_id <-
    data_gridpoints_raw %>%
    dplyr::distinct(.data$sample_name) %>%
    dplyr::left_join(
      dplyr::tbl(sel_con, "Samples") %>%
        dplyr::select("sample_id", "sample_name") %>%
        dplyr::collect(),
      by = dplyr::join_by("sample_name")
    ) %>%
    dplyr::distinct(.data$sample_id) %>%
    purrr::chuck("sample_id")

  vec_relevant_vegetation_sample_names <-
    dplyr::tbl(sel_con, "AbioticDataReference") %>%
    dplyr::select("sample_id", "sample_ref_id") %>%
    dplyr::filter(
      .data$sample_ref_id %in% vec_gridpoints_sample_id
    ) %>%
    dplyr::distinct(.data$sample_id) %>%
    dplyr::left_join(
      dplyr::tbl(sel_con, "Samples") %>%
        dplyr::select("sample_id", "sample_name"),
      by = dplyr::join_by("sample_id")
    ) %>%
    dplyr::collect() %>%
    purrr::chuck("sample_name")

  rm(vec_gridpoints_sample_id, envir = current_env)

  data_bd_vegetation_sub <-
    data_bd_vegetation_raw %>%
    dplyr::filter(
      !.data$sample_name %in% vec_relevant_vegetation_sample_names
    )

  rm(data_bd_vegetation_raw, envir = current_env)

  # nest the and create dictionary of samples and link to gridpoints samples
  data_bd_vegetation_nest <-
    data_bd_vegetation_sub %>%
    dplyr::distinct(
      .data$dataset_name, .data$sample_name,
      .data$coord_long, .data$coord_lat,
      .data$age
    ) %>%
    dplyr::group_by(.data$coord_long, .data$coord_lat, .data$age) %>%
    tidyr::nest(data = -c("coord_long", "coord_lat", "age")) %>%
    dplyr::ungroup() %>%
    dplyr::mutate(
      geo_veg_sample = paste0(
        "dummy_",
        dplyr::row_number()
      )
    )

  data_bd_vegetation_nest_ref <-
    data_bd_vegetation_nest %>%
    dplyr::select(
      "geo_veg_sample", "data"
    ) %>%
    tidyr::unnest(data)

  data_bd_vegetation_to_limit <-
    data_bd_vegetation_nest %>%
    dplyr::select(
      "geo_veg_sample",
      "coord_long", "coord_lat", "age"
    )

  rm(data_bd_vegetation_nest, envir = current_env)

  data_gridpoints_to_limit <-
    data_gridpoints_raw %>%
    dplyr::distinct(
      .data$sample_name,
      .data$coord_long, .data$coord_lat,
      .data$age
    ) %>%
    dplyr::rename(
      sample = "sample_name"
    ) %>%
    dplyr::rename_with(
      ~ paste0("grid_", .x)
    )

  rm(data_gridpoints_raw, envir = current_env)

  gc(verbose = FALSE)

  data_bd_vegetation_to_limit %>%
    dplyr::mutate(
      batch = 1 + (dplyr::row_number() - 1) %/% 500
    ) %>%
    dplyr::group_by(.data$batch) %>%
    tidyr::nest(data = -"batch") %>%
    dplyr::ungroup() %>%
    purrr::chuck("data") %>%
    rlang::set_names(paste0("batch_", seq_along(.))) %>%
    purrr::iwalk(
      .progress = "filtering gripoints samples",
      .f = ~ {
        message(.y)

        data_res_link <-
          get_gridpoints_link(
            data_source = .x,
            data_source_gridpoints = data_gridpoints_to_limit,
            sel_grid_size_degree = sel_grid_size_degree,
            sel_distance_km = sel_distance_km,
            sel_distance_years = sel_distance_years
          )

        data_sample_link_to_import <-
          dplyr::left_join(
            data_res_link,
            data_bd_vegetation_nest_ref,
            by = "geo_veg_sample",
            relationship = "many-to-many"
           ) %>%
          dplyr::select(
            "sample_name",
            sample_name_gridpoints = "grid_sample",
            "distance_in_km",
            "distance_in_years"
          )

        vec_unique_samples_gridpoints <-
          data_sample_link_to_import %>%
          dplyr::distinct(.data$sample_name_gridpoints) %>%
          purrr::chuck("sample_name_gridpoints")

        data_to_import <-
          data_source %>%
          dplyr::filter(.data$sample_name %in% vec_unique_samples_gridpoints)

        data_datasets_to_import <-
          data_to_import %>%
          dplyr::distinct(
            .data$dataset_name,
            .data$coord_long, .data$coord_lat,
            .data$data_source_desc, .data$dataset_type,
            .data$dataset_source_type,
            .data$data_source_type_reference, .data$data_source_reference,
            .data$dataset_reference
          )

        # add datasets
        dataset_id_db <-
          add_datasets(
            data_source = data_datasets_to_import,
            con = sel_con,
            data_type = dataset_type_db,
            data_source_type = dataset_source_type_db,
            dataset_source = data_source_id_db
          )

        data_samples_to_import <-
          data_to_import %>%
          dplyr::distinct(
            .data$dataset_name, .data$sample_name,
            .data$age, .data$sample_size, .data$description,
            .data$sample_reference
          )

        # add samples
        samples_id_db <-
          add_samples(
            data_source = data_samples_to_import,
            con = sel_con
          )

        # add dataset-sample
        add_dataset_sample(
          data_source = data_samples_to_import,
          con = sel_con,
          dataset_id = dataset_id_db,
          sample_id = samples_id_db
        )

        # add abiotic data ref
        add_abiotic_data_ref(
          data_source = data_sample_link_to_import,
          con = sel_con
        )

        gc(verbose = FALSE)
      }
    )
}
