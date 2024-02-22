add_taxa <- function(data_source, con) {
  data_taxa_id_db <-
    add_taxa_id(
      data_source = data_source,
      con = con
    )

  data_taxa_reference_id_db <-
    add_taxa_reference_id(
      data_source = data_source,
      con = con
    )

  add_taxa_reference(
    data_source = data_source,
    con = con,
    taxa_reference_id = data_taxa_reference_id_db
  )

  return(data_taxa_id_db)
}
