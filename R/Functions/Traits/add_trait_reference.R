add_trait_reference <- function(data_source, trait_reference_id, con) {
  assertthat::assert_that(
    assertthat::has_name(
      data_source, c(
        "trait_full_name",
        "trait_reference"
      )
    ),
    msg = "data_source must have a column named trait_full_name and trait_reference"
  )

  trait_id_db <-
    dplyr::tbl(con, "Traits") %>%
    dplyr::distinct(trait_id, trait_name) %>%
    dplyr::collect()

  trait_reference_lookup <-
    data_source %>%
    dplyr::distinct(trait_full_name, trait_reference) %>%
    tidyr::drop_na() %>%
    dplyr::left_join(
      trait_reference_id,
      by = dplyr::join_by(trait_reference == reference_detail)
    ) %>%
    dplyr::left_join(
      trait_id_db,
      by = dplyr::join_by(trait_full_name == trait_name)
    ) %>%
    dplyr::select(trait_id, reference_id)

  trait_reference_unique <-
    trait_reference_lookup %>%
    dplyr::anti_join(
      dplyr::tbl(con, "TraitsReference") %>%
        dplyr::collect(),
      by = dplyr::join_by(trait_id, reference_id)
    )

  add_to_db(
    conn = con,
    data = trait_reference_unique,
    table_name = "TraitsReference",
    overwrite_test = TRUE
  )
}
