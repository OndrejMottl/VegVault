get_traits <- function(con) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  # test for presence of abiotic and/or trait values and output a warning
  #  that the column is going to be renamed

  data_res <-
    sel_data %>%
    dplyr::left_join(
      dplyr::tbl(sel_con, "TraitsValue"),
      by = c("dataset_id", "sample_id"),
      suffix = c("", "_trait")
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
