# Stand-ins for the outputs of the gridpoint stage, for the given sample
#   sources: one position per distinct (longitude, latitude, age) of the
#   samples with coordinates plus one position that no sample uses, three
#   gridpoints, and links from every used position to the first two
#   gridpoints and from the unused position to the third only. Returns a
#   list with `data_positions`, `data_position_links` and `data_gridpoints`.
build_test_position_inputs <- function(list_source_tables) {
  data_sample_coordinates <-
    list_source_tables |>
    purrr::map(
      .f = ~ purrr::chuck(.x, "datasets") |>
        dplyr::select(dataset_name, coord_long, coord_lat) |>
        dplyr::inner_join(
          purrr::chuck(.x, "dataset_samples"),
          by = dplyr::join_by(dataset_name)
        ) |>
        dplyr::inner_join(
          dplyr::select(purrr::chuck(.x, "samples"), sample_name, age),
          by = dplyr::join_by(sample_name)
        )
    ) |>
    purrr::list_rbind(
      ptype = tibble::tibble(
        dataset_name = base::character(0),
        coord_long = base::double(0),
        coord_lat = base::double(0),
        sample_name = base::character(0),
        age = base::double(0)
      )
    ) |>
    dplyr::filter(
      !base::is.na(coord_long),
      !base::is.na(coord_lat)
    )

  data_positions <-
    data_sample_coordinates |>
    dplyr::distinct(coord_long, coord_lat, age) |>
    dplyr::bind_rows(
      tibble::tibble(coord_long = 0.5, coord_lat = 0.5, age = 123)
    ) |>
    dplyr::arrange(coord_long, coord_lat, age) |>
    dplyr::mutate(position_id = dplyr::row_number(), .before = 1L)

  data_gridpoints <-
    tibble::tibble(
      gridpoint_id = c(1L, 2L, 3L),
      coord_long = c(10, 10, 0.5),
      coord_lat = c(50, 50, 0.5),
      age = c(0, 500, 0),
      dataset_name = c("geo_10_50", "geo_10_50", "geo_0.5_0.5"),
      sample_name = c("geo_10_50_0", "geo_10_50_500", "geo_0.5_0.5_0")
    )

  vec_used_positions <-
    data_positions |>
    dplyr::filter(age != 123) |>
    dplyr::pull(position_id)

  id_unused_position <-
    data_positions |>
    dplyr::filter(age == 123) |>
    dplyr::pull(position_id)

  data_position_links <-
    dplyr::bind_rows(
      tibble::tibble(
        position_id = vec_used_positions,
        gridpoint_id = 1L,
        distance_in_km = 5L,
        distance_in_years = 0L
      ),
      tibble::tibble(
        position_id = vec_used_positions,
        gridpoint_id = 2L,
        distance_in_km = 5L,
        distance_in_years = 500L
      ),
      tibble::tibble(
        position_id = id_unused_position,
        gridpoint_id = 3L,
        distance_in_km = 1L,
        distance_in_years = 0L
      )
    )

  res <-
    base::list(
      data_positions = data_positions,
      data_position_links = data_position_links,
      data_gridpoints = data_gridpoints
    )

  return(res)
}
