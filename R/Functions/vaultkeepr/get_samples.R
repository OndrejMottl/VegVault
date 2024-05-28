get_samples <- function(con) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  data_res <-
    sel_data %>%
    dplyr::inner_join(
      dplyr::tbl(sel_con, "DatasetSample"),
      by = "dataset_id"
    ) %>%
    dplyr::inner_join(
      dplyr::tbl(sel_con, "Samples"),
      by = "sample_id"
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