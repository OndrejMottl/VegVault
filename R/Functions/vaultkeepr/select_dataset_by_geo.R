select_dataset_by_geo <- function(con, long_lim = c(-180, 180), lat_lim = c(-90, 90)) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data


  long_lim_min <- as.numeric(eval(min(long_lim)))
  long_lim_max <- as.numeric(eval(max(long_lim)))

  lat_lim_min <- as.numeric(eval(min(lat_lim)))
  lat_lim_max <- as.numeric(eval(max(lat_lim)))


  assertthat::assert_that(
    all(c("coord_long", "coord_lat") %in% colnames(sel_data))
  )

  data_filter <-
    sel_data %>%
    dplyr::filter(!is.na(coord_long)) %>%
    dplyr::filter(!is.na(coord_lat))

  data_res <-
    data_filter %>%
    dplyr::filter(
      coord_long >= long_lim_min
    ) %>%
    dplyr::filter(
      coord_long <= long_lim_max
    ) %>%
    dplyr::filter(
      coord_lat >= lat_lim_min
    ) %>%
    dplyr::filter(
      coord_lat <= lat_lim_max
    )

  res <-
    structure(
      list(
        data = data_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}