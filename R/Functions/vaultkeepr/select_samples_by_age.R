select_samples_by_age <- function(con, age_lim = c(-Inf, Inf)) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  age_lim_min <- as.numeric(eval(min(age_lim)))
  age_lim_max <- as.numeric(eval(max(age_lim)))

  assertthat::assert_that(
    "age" %in% colnames(sel_data),
    msg = paste(
      "The dataset does not contain `age` columns. Please add",
      "`get_samples()` to the pipe before this function."
    )
  )

  assertthat::assert_that(
    "dataset_type" %in% colnames(sel_data),
    msg = paste(
      "The dataset does not contain `dataset_type` columns. Please add",
      "`select_dataset_by_type()` to the pipe before this function."
    )
  )

  data_res <-
    sel_data %>%
    dplyr::mutate(
      keep = dplyr::case_when(
        .default = TRUE,
        is.na(age) &
          (dataset_type %in% c(
            "vegetation_plot",
            "fossil_pollen_archive",
            "gridpoints"
          )) ~ FALSE,
        (age <= age_lim_min) &
          (dataset_type %in% c(
            "vegetation_plot",
            "fossil_pollen_archive",
            "gridpoints"
          )) ~ FALSE,
        (age >= age_lim_max) &
          (dataset_type %in% c(
            "vegetation_plot",
            "fossil_pollen_archive",
            "gridpoints"
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
