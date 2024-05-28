select_dataset_by_type <- function(con, sel_type) {
  # test various things

  sel_data <- con$data

  sel_con <- con$db_con

  dat_res <-
    sel_data %>%
    dplyr::left_join(
      dplyr::tbl(sel_con, "DatasetTypeID"),
      by = "dataset_type_id"
    ) %>%
    dplyr::filter(
      dataset_type %in% sel_type
    )

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