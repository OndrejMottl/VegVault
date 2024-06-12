get_taxa <- function(
    con,
    classify_to = c("original", "species", "genus", "family")) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  # test for presence of abiotic and/or trait values and output a warning
  #  that the column is going to be renamed

  data_taxa <-
    classify_taxa(
      data_source = dplyr::tbl(sel_con, "SampleTaxa"),
      con = sel_con,
      to = classify_to
    )

  data_res <-
    sel_data %>%
    dplyr::left_join(
      data_taxa,
      by = "sample_id",
      suffix = c("", "_taxa")
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
