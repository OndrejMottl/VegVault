harmonise_taxa <- function(con, to = c("original", "species", "genus", "family")) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  to_long <- switch(to,
    original = "taxon_id",
    species = "taxon_species",
    genus = "taxon_genus",
    family = "taxon_family",
  )

  if (to_long == "taxon_id") {
    return(con)
  }

  data_class_sub <-
    dplyr::tbl(sel_con, "TaxonClassification") %>%
    dplyr::select(
      taxon_id,
      dplyr::all_of(to_long)
    ) %>%
    dplyr::rename(
      taxon_id_new = !!to_long
    )

  data_res <-
    sel_data %>%
    dplyr::left_join(
      data_class_sub,
      by = "taxon_id"
    ) %>%
    dplyr::select(
      -taxon_id
    ) %>%
    dplyr::rename(
      taxon_id = taxon_id_new
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