get_datasets <- function(con) {
  sel_data <- con$data

  if (
    nrow(sel_data) > 0
  ) {
    stop("Vault already has some data. `get_datasets()` should be selected first")
  }

  # test various things
  sel_con <- con$db_con

  dat_res <-
    dplyr::tbl(sel_con, "Datasets")

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