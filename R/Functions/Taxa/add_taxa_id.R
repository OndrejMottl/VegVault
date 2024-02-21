add_taxa_id <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "taxon_name"),
    msg = "data_source must have a column named taxon_name"
  )

  taxon_name_db <-
    dplyr::tbl(con, "Taxa") %>%
    dplyr::distinct(taxon_name) %>%
    dplyr::collect() %>%
    purrr::chuck("taxon_name")

  taxa <-
    data_source %>%
    dplyr::distinct(taxon_name) %>%
    tidyr::drop_na() %>%
    dplyr::filter(
      !taxon_name %in% taxon_name_db
    )

  add_to_db(
    conn = con,
    data = taxa,
    table_name = "Taxa"
  )

  taxa_id <-
    dplyr::tbl(con, "Taxa") %>%
    dplyr::select(taxon_id, taxon_name) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(taxon_name),
      by = dplyr::join_by(taxon_name)
    )

  return(taxa_id)
}
