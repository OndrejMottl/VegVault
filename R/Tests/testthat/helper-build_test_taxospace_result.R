# A stand-in for the result of taxospace::get_classification(): one row per
#   name of `vec_names`, in its order, with `sel_name`, `data_resolve`,
#   `id` (the GBIF id as text) and `classification` (a tibble of `name`,
#   `rank` and `id`, or NULL). Like the services, it treats letter case
#   strictly; classify_taxa() sends names with only their first letter in
#   capitals. The names this stand-in knows: "Quercus robur", "Quercus
#   robur l.", "Juglans nigra" and "Vaccinium vitis-idaea" (species),
#   "Betula" (genus), "Poaceae" (family), "Above family" (classified only to
#   its order), "Ambrosia" (a genus matched to the GBIF placeholder species
#   "Ambrosia spec") and "Tied name" (two GBIF taxa, ids 1000 and 200,
#   matched equally well, so two rows), all in the kingdom Plantae;
#   "Dryas sp" (matched equally well to the butterfly genus Dryas, kingdom
#   Animalia, id 100, and to the plant genus Dryas, kingdom Plantae, id 400)
#   and "Coniferae undiff" (matched only to the animal genus Coniferina, id
#   300). Every other name gets one unclassified row.
build_test_taxospace_result <- function(vec_names) {
  data_known <-
    tibble::tribble(
      ~sel_name, ~id, ~species, ~genus, ~family, ~kingdom,
      "Quercus robur", "2878688", "Quercus robur", "Quercus", "Fagaceae",
      "Plantae",
      "Quercus robur l.", "2878688", "Quercus robur", "Quercus", "Fagaceae",
      "Plantae",
      "Juglans nigra", "3054368", "Juglans nigra", "Juglans",
      "Juglandaceae", "Plantae",
      "Vaccinium vitis-idaea", "2882835", "Vaccinium vitis-idaea",
      "Vaccinium", "Ericaceae", "Plantae",
      "Betula", "2875008", NA, "Betula", "Betulaceae", "Plantae",
      "Poaceae", "3073", NA, NA, "Poaceae", "Plantae",
      "Above family", "5", NA, NA, NA, "Plantae",
      "Ambrosia", "11491555", "Ambrosia spec", "Ambrosia", "Asteraceae",
      "Plantae",
      "Tied name", "1000", "Species b", "Genus b", "Family b", "Plantae",
      "Tied name", "200", "Species a", "Genus a", "Family a", "Plantae",
      "Dryas sp", "100", NA, "Dryas", "Nymphalidae", "Animalia",
      "Dryas sp", "400", NA, "Dryas", "Rosaceae", "Plantae",
      "Coniferae undiff", "300", NA, "Coniferina", NA, "Animalia"
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
        .l = base::list(id, species, genus, family, kingdom),
        .f = ~ if (
          base::is.na(..1)
        ) {
          NULL
        } else {
          tibble::tibble(
            name = c(..5, "Test order", ..4, ..3, ..2),
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
