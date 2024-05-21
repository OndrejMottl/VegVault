select_samples_by_age <- function(con, age_lim = c(-Inf, Inf)) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  age_lim_min <- as.numeric(eval(min(age_lim)))
  age_lim_max <- as.numeric(eval(max(age_lim)))

  data_filter <-
    sel_data %>%
    dplyr::filter(!is.na(age))

  data_res <-
    data_filter %>%
    dplyr::filter(
      age >= age_lim_min
    ) %>%
    dplyr::filter(
      age <= age_lim_max
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
