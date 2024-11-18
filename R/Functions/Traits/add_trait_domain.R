add_trait_domain <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, "trait_domain_name"),
    msg = "data_source must have a column named trait_domain_name"
  )

  trait_domain_name_db <-
    dplyr::tbl(con, "TraitsDomain") %>%
    dplyr::distinct(trait_domain_name) %>%
    dplyr::collect() %>%
    purrr::chuck("trait_domain_name")

  trait_domain <-
    data_source %>%
    dplyr::distinct(trait_domain_name) %>%
    tidyr::drop_na() %>%
    dplyr::filter(
      !trait_domain_name %in% trait_domain_name_db
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
