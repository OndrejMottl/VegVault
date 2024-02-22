add_taxa_reference_id <- function(data_source, con){
    assertthat::assert_that(
      assertthat::has_name(data_source, "taxon_reference"),
      msg = "data_source must have a column named taxon_reference"
    )

    reference_detail_db <-
      dplyr::tbl(con, "References") %>%
      dplyr::distinct(reference_detail) %>%
      dplyr::collect() %>%
      purrr::pluck("reference_detail")

    taxa_reference <-
      data_source %>%
      dplyr::distinct(taxon_reference) %>%
      tidyr::drop_na() %>%
      dplyr::rename(
        reference_detail = taxon_reference
      ) %>%
      dplyr::filter(
        !reference_detail %in% reference_detail_db
      )

    add_to_db(
      conn = con,
      data = taxa_reference,
      table_name = "References"
    )

    taxa_reference_id <-
      dplyr::tbl(con, "References") %>%
      dplyr::select(reference_id, reference_detail) %>%
      dplyr::collect() %>%
      dplyr::inner_join(
        data_source %>%
          dplyr::distinct(taxon_reference),
        by = dplyr::join_by(reference_detail == taxon_reference)
      )

    return(taxa_reference_id)
}