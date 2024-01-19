add_trait_domain <- function(data_source, con) {
  trait_domain <-
    data_source %>%
    dplyr::distinct(trait_domain_name) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "TraitsDomain") %>%
        dplyr::select(trait_domain_name) %>%
        dplyr::collect(),
      by = dplyr::join_by(trait_domain_name)
    )

  add_to_db(
    conn = con,
    data = trait_domain,
    table_name = "TraitsDomain"
  )

  trait_domain_id <-
    dplyr::tbl(con, "TraitsDomain") %>%
    dplyr::select(trait_domain_id, trait_domain_name) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(trait_domain_name),
      by = dplyr::join_by(trait_domain_name)
    )

    return(trait_domain_id)
}