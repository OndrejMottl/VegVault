add_taxa_reference <- function(data_source, taxa_reference_id, con) {
   assertthat::assert_that(
     assertthat::has_name(
       data_source, c(
         "taxon_name",
         "taxon_reference"
       )
     ),
     msg = "data_source must have a column named taxon_name and taxon_reference"
   )

   taxa_id_db <-
     dplyr::tbl(con, "Taxa") %>%
     dplyr::distinct(taxon_id, taxon_name) %>%
     dplyr::collect()

   taxa_reference_lookup <-
     data_source %>%
     dplyr::distinct(taxon_name, taxon_reference) %>%
     tidyr::drop_na() %>%
     dplyr::left_join(
       taxa_reference_id,
       by = dplyr::join_by(taxon_reference == reference_detail)
     ) %>%
     dplyr::left_join(
       taxa_id_db,
       by = dplyr::join_by(taxon_name)
     ) %>%
     dplyr::select(taxon_id, reference_id)

   taxa_reference_unique <-
     taxa_reference_lookup %>%
     dplyr::anti_join(
       dplyr::tbl(con, "TaxonReference") %>%
         dplyr::collect(),
       by = dplyr::join_by(taxon_id, reference_id)
     )

   add_to_db(
     conn = con,
     data = taxa_reference_unique,
     table_name = "TaxonReference",
     overwrite_test = TRUE
   )
}