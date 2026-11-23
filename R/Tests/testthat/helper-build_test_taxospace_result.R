# A stand-in for the result of taxospace::get_classification(): one row per
#   name of `vec_names`, in its order, with `sel_name`, `data_resolve`,
#   `id` (the GBIF id as text) and `classification` (a tibble of `name`,
#   `rank` and `id`, or NULL). The names this stand-in knows:
#   "Quercus robur" and "Quercus robur L." (species), "Betula" (genus),
#   "Poaceae" (family), "Above family" (classified only to its order),
#   "Ambrosia" (a genus matched to the GBIF placeholder species
#   "Ambrosia spec") and "Tied name" (two GBIF taxa, ids 1000 and 200,
#   matched equally well, so two rows). Every other name gets one
#   unclassified row.
build_test_taxospace_result <- function(vec_names) {
  data_known <-
    tibble::tribble(
      ~sel_name, ~id, ~species, ~genus, ~family,
      "Quercus robur", "2878688", "Quercus robur", "Quercus", "Fagaceae",
      "Quercus robur L.", "2878688", "Quercus robur", "Quercus", "Fagaceae",
      "Betula", "2875008", NA, "Betula", "Betulaceae",
      "Poaceae", "3073", NA, NA, "Poaceae",
      "Above family", "5", NA, NA, NA,
      "Ambrosia", "11491555", "Ambrosia spec", "Ambrosia", "Asteraceae",
      "Tied name", "1000", "Species b", "Genus b", "Family b",
      "Tied name", "200", "Species a", "Genus a", "Family a"
    )

  data_rows <-
    tibble::tibble(sel_name = vec_names) |>
    dplyr::left_join(
      data_known,
      by = dplyr::join_by(sel_name),
      relationship = "one-to-many"
    )

  res <-
    data_rows |>
    dplyr::mutate(
      data_resolve = base::vector(mode = "list", length = dplyr::n()),
      classification = purrr::pmap(
        .l = base::list(id, species, genus, family),
        .f = ~ if (
          base::is.na(..1)
        ) {
          NULL
        } else {
          tibble::tibble(
            name = c("Plantae", "Test order", ..4, ..3, ..2),
            rank = c("kingdom", "order", "family", "genus", "species"),
            id = c(6L, 7L, 8L, 9L, base::as.integer(..1))
          ) |>
            dplyr::filter(!base::is.na(name))
        }
      )
    ) |>
    dplyr::select(sel_name, data_resolve, id, classification)

  return(res)
}
