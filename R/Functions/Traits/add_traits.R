add_traits <- function(data_source, con) {
  data_trait_domain_id_db <-
    add_trait_domain(
      data_source = data_source,
      con = con
    )

  data_traits_id_db <-
    add_trait_id(
      data_source = data_source,
      trait_domain_id = data_trait_domain_id_db,
      con = con
    )

  data_traits_reference_id_db <-
    add_trait_reference_id(
      data_source = data_source,
      con = con
    )

  add_trait_reference(
    data_source = data_source,
    trait_reference_id = data_traits_reference_id_db,
    con = con
  )

  return(data_traits_id_db)
}
