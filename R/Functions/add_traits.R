add_traits <- function(data_source, trait_domain_id, con) {
  traits <-
    data_source %>%
    dplyr::distinct(trait_domain_name, trait_full_name) %>%
    dplyr::left_join(
      trait_domain_id,
      by = dplyr::join_by(trait_domain_name)
    ) %>%
    dplyr::select(-trait_domain_name) %>%
    dplyr::rename(
      trait_name = trait_full_name
    ) %>%
    dplyr::anti_join(
      dplyr::tbl(con, "Traits") %>%
        dplyr::select(trait_name) %>%
        dplyr::collect(),
      by = dplyr::join_by(trait_name)
    )

  add_to_db(
    conn = con,
    data = traits,
    table_name = "Traits"
  )

  traits_id <-
    dplyr::tbl(con, "Traits") %>%
    dplyr::select(trait_id, trait_name) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_source %>%
        dplyr::distinct(trait_full_name),
      by = dplyr::join_by(trait_name == trait_full_name)
    )
}