classify_taxa <- function(data_source, con, to = c("original", "species", "genus", "family")) {
  # test various things
  to_long <- switch(to,
    original = "taxon_id",
    species = "taxon_species",
    genus = "taxon_genus",
    family = "taxon_family",
  )

  if (to_long == "taxon_id") {
    return(data_source)
  }

  data_class_sub <-
    dplyr::tbl(con, "TaxonClassification") %>%
    dplyr::select(
      taxon_id,
      dplyr::all_of(to_long)
    ) %>%
    dplyr::rename(
      taxon_id_new = !!to_long
    )

  data_res <-
    data_source %>%
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

  return(data_res)
}
