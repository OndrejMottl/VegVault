add_taxa_classification <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "taxon_id",
        "taxon_species",
        "taxon_genus",
        "taxon_family"
      )
    ),
    msg = "data_source must have a column named taxon_name"
  )

  taxa_id_db <-
    dplyr::tbl(con, "TaxonClassification") %>%
    dplyr::distinct(taxon_id) %>%
    dplyr::collect() %>%
    purrr::chuck("taxon_id")

  taxa_unique <-
    data_source %>%
    dplyr::filter(
      !taxon_id %in% taxa_id_db
    ) 

  add_to_db(
    conn = con,
    data = taxa_unique,
    table_name = "TaxonClassification",
    overwrite_test = TRUE
  )

}
