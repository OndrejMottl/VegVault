add_trait_id <- function(data_source, trait_domain_id, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source,
      c(
        "trait_domain_name",
        "trait_full_name"
      )
    ),
    msg = "data_source must have a column named trait_domain_name and trait_full_name"
  )

  assertthat::assert_that(
    assertthat::has_name(
      trait_domain_id,
      c(
        "trait_domain_id",
        "trait_domain_name"
      )
    ),
    msg = "trait_domain_id must have a column named trait_domain_id and trait_domain_name"
  )

  trait_name_db <-
    dplyr::tbl(con, "Traits") %>%
    dplyr::distinct(trait_name) %>%
    dplyr::collect() %>%
    purrr::chuck("trait_name")

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
    dplyr::filter(
      !trait_name %in% trait_name_db
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

  return(traits_id)
}
