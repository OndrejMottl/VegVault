select_dataset_by_geo <- function(
    con,
    long_lim = c(-180, 180),
    lat_lim = c(-90, 90),
    sel_dataset_type = c("vegetation_plot", "fossil_pollen_archive", "gridpoints")) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data


  long_lim_min <- as.numeric(eval(min(long_lim)))
  long_lim_max <- as.numeric(eval(max(long_lim)))

  lat_lim_min <- as.numeric(eval(min(lat_lim)))
  lat_lim_max <- as.numeric(eval(max(lat_lim)))

  assertthat::assert_that(
    all(c("coord_long", "coord_lat") %in% colnames(sel_data)),
    msg = "The data does not contain lat/long columns for this function."
  )

  assertthat::assert_that(
    "dataset_type" %in% colnames(sel_data),
    msg = paste(
      "The data does not contain `dataset_type` columns. Please add",
      "`select_dataset_by_type()` to the pipe before this function."
    )
  )

  vec_present_dataset_type <-
    sel_data %>%
    dplyr::distinct(dataset_type) %>%
    dplyr::pull("dataset_type")

  vec_common_dataset_type <-
    intersect(vec_present_dataset_type, sel_dataset_type)

  if (
    !all(sel_dataset_type %in% vec_present_dataset_type)
  ) {
    warning(
      paste(
        "The data does not contain the all dataset types specified in",
        "`sel_dataset_type`.", "\n",
        "Changing `sel_dataset_type` to the dataset types",
        "present in the data as:",
        paste(vec_common_dataset_type, collapse = ", ")
      )
    )

    sel_dataset_type <- vec_common_dataset_type
  }

  if (
    !all(vec_present_dataset_type %in% sel_dataset_type)
  ) {
    dataset_type_missing <-
      setdiff(vec_present_dataset_type, sel_dataset_type)

    warning(
      paste(
        "The selected dataset type will not be filtered by geo:",
        paste(dataset_type_missing, collapse = ", ")
      )
    )
  }


  data_res <-
    sel_data %>%
    dplyr::mutate(
      keep = dplyr::case_when(
        .default = TRUE,
        is.na(coord_long) &
          (dataset_type %in% c(
            sel_dataset_type
          )) ~ FALSE,
        is.na(coord_lat) &
          (dataset_type %in% c(
            sel_dataset_type
          )) ~ FALSE,
        (coord_long < long_lim_min) &
          (dataset_type %in% c(
            sel_dataset_type
          )) ~ FALSE,
        (coord_long > long_lim_max) &
          (dataset_type %in% c(
            sel_dataset_type
          )) ~ FALSE,
        (coord_lat < lat_lim_min) &
          (dataset_type %in% c(
            sel_dataset_type
          )) ~ FALSE,
        (coord_lat > lat_lim_max) &
          (dataset_type %in% c(
            sel_dataset_type
          )) ~ FALSE
      )
    ) %>%
    dplyr::filter(
      keep == TRUE
    ) %>%
    dplyr::select(-keep)

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
