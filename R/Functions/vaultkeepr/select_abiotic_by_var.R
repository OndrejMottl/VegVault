select_abiotic_by_var <- function(con, sel_var) {
  # test various things

  sel_data <- con$data

  sel_con <- con$db_con

  dat_res <-
    sel_data %>%
    dplyr::left_join(
      dplyr::tbl(sel_con, "AbioticVariable"),
      by = "abiotic_variable_id"
    ) %>%
    dplyr::mutate(
      keep = dplyr::case_when(
        .default = TRUE,
        !(abiotic_variable_name %in% sel_var) & dataset_type == "gridpoints" ~ FALSE
      )
    ) %>%
    dplyr::filter(
      keep == TRUE
    ) %>%
    dplyr::select(-keep)

  res <-
    structure(
      list(
        data = dat_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}
