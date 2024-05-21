select_taxa <- function(con, sel_taxa) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  data_res <-
    sel_data %>%
    dplyr::left_join(
      dplyr::tbl(sel_con, "Taxa"),
      by = "taxon_id"
    ) %>%
    dplyr::filter(
      taxon_name %in% sel_taxa
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