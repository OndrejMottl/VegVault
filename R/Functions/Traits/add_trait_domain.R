add_trait_domain <- function(data_source, con) {
  assertthat::assert_that(
    assertthat::has_name(data_source, c("trait_domain_name", "trait_unit")),
    msg = "data_source must have trait_domain_name and trait_unit columns"
  )

  data_domain_contract <-
    data_source %>%
    dplyr::distinct(trait_domain_name, trait_unit) %>%
    tidyr::drop_na()

  data_domain_conflicts <-
    data_domain_contract %>%
    dplyr::count(trait_domain_name, name = "n_units") %>%
    dplyr::filter(.data$n_units != 1L)

  if (nrow(data_domain_conflicts) > 0L) {
    cli::cli_abort("Each trait domain must have exactly one canonical unit.")
  }

  trait_domain_name_db <-
    dplyr::tbl(con, "TraitsDomain") %>%
    dplyr::distinct(trait_domain_name) %>%
    dplyr::collect() %>%
    purrr::chuck("trait_domain_name")

  trait_domain <-
    data_domain_contract %>%
    dplyr::filter(!trait_domain_name %in% trait_domain_name_db)

  add_to_db(
    conn = con,
    data = trait_domain,
    table_name = "TraitsDomain"
  )

  trait_domain_id <-
    dplyr::tbl(con, "TraitsDomain") %>%
    dplyr::select(trait_domain_id, trait_domain_name, trait_unit) %>%
    dplyr::collect() %>%
    dplyr::inner_join(
      data_domain_contract,
      by = dplyr::join_by(trait_domain_name, trait_unit)
    )

  if (nrow(trait_domain_id) != nrow(data_domain_contract)) {
    cli::cli_abort("Trait-domain units conflict with the database contract.")
  }

  return(
    trait_domain_id %>%
      dplyr::select(trait_domain_id, trait_domain_name)
  )
}
