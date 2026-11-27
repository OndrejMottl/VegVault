#' @title Classify taxon names to their species, genus and family
#' @description
#' Classify taxon names with `taxospace::get_classification()`, as v1.0.0
#' did (names matched by the Global Names Verifier and classified in the
#' GBIF Backbone Taxonomy), and return the species, genus and family of
#' each name.
#' @param vec_taxon_names
#' Character vector of unique taxon names, without missing or empty
#' values.
#' @param name_check_taxon
#' Character scalar. A name that the services always classify
#' (`build: classification: check_taxon` of `config.yml`). It is classified
#' with every batch; a batch in which it gets no family aborts.
#' @param sel_db_name
#' Character scalar. The name-matching service of `taxospace`
#' (`build: classification: db_name`, `"gnr"` in v1.0.0).
#' @param sel_db_class
#' Character scalar. The classification database of `taxospace`
#' (`build: classification: db_class`, `"gbif"` in v1.0.0).
#' @param flag_only_exact_match
#' Logical scalar, passed to `taxospace` as `use_only_exact_match`
#' (`build: classification: only_exact_match`). When `TRUE`, only the
#' accepted GBIF taxa of a matched name are considered; when `FALSE`
#' (default), the GBIF taxon with the highest confidence is taken, so that,
#' for example, "Ledum Type" is classified in Rhododendron and "Lagotis
#' minor" in Lagotis rather than in a fungus and a ciliate.
#' @param sel_kingdom
#' Character scalar. The kingdom of the GBIF Backbone Taxonomy whose taxa
#' are kept (`build: classification: kingdom`; default `"Plantae"`). A
#' name matched only to taxa of other kingdoms stays unclassified.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A tibble with `taxon_name`, `species_name`, `genus_name` and
#' `family_name`, one row per name of `vec_taxon_names`, in its order. A
#' rank the name does not reach, and every rank of a name that is not
#' classified, is missing.
#' @details
#' Names are classified without the `taxospace` cache
#' (`use_cache = FALSE`), as in the second pass of v1.0.0, because the
#' cache files of similar names share a file name. The Global Names
#' Verifier treats letter case strictly (the service of v1.0.0 did not): a
#' name in capitals, such as "VACCINIUM VITIS-IDAEA", is not matched, and a
#' name with a capitalised second word, such as the pollen type "Juglans
#' Nigra", is matched to its genus only. Each name, and the check name, is
#' therefore sent with only its first letter in capitals ("Vaccinium
#' vitis-idaea", "Juglans nigra"; an author "L." becomes "l.", which is
#' still matched), and each such form is sent once. The result keeps the
#' names as written. Only the taxa of the
#' kingdom `sel_kingdom` count: the Global Names Verifier also matches
#' names to animals (for example "Dryas sp" to the butterfly genus Dryas as
#' well as the plant genus, and "Coniferae Undiff" to the animal genus
#' Coniferina), which v1.0.0 kept. When a name matches several taxa of the
#' kingdom equally well, the taxon with the smallest GBIF id is used, as in
#' v1.0.0. A rank is the first name of that rank in the
#' classification. A species name ending in " spec" is a placeholder of
#' the GBIF Backbone Taxonomy for an unnamed species of a genus (some
#' genera, such as Artemisia, match it today), so the name gets no
#' species, only its genus and family; v1.0.0 has no such names.
#'
#' `taxospace` returns a name it could not send to the matching service as
#' unclassified, so a batch run while a service is down would look like a
#' batch of unknown names. The check name guards against this: when it
#' gets no family, the function aborts, so `{targets}` keeps no result and
#' classifies the batch again in the next run. Needs internet access.
#'
#' `taxospace` 0.0.9005 stops the whole call ("data_source must have at
#' least one row") when a name, classified together with other names, is
#' matched to a taxon that the GBIF Backbone Taxonomy does not have; the
#' FOSSILPOL pollen types "Spermatophyta Undiff(Shrubs)" and "Spermatophyta
#' Undiff(Trees)" are matched to "Spermatophyta". On this error, and only
#' on it, the batch is classified again one name at a time: a name that
#' fails alone, or comes back without a GBIF taxon, stays unclassified, and
#' a warning lists the unclassified names, as sent. Any other error stops
#' the batch,
#' and the check name is classified and checked as before.
#' Aborts when a name is missing, empty or repeated.
#' @seealso [prepare_taxon_batches()], [prepare_classification_tables()]
#' @examples
#' \dontrun{
#' data_classification <-
#'   classify_taxa(
#'     vec_taxon_names = c("Quercus robur", "Betula"),
#'     name_check_taxon = "Quercus robur"
#'   )
#' }
classify_taxa <- function(
  vec_taxon_names,
  name_check_taxon,
  sel_db_name = "gnr",
  sel_db_class = "gbif",
  flag_only_exact_match = FALSE,
  sel_kingdom = "Plantae",
  verbose = TRUE
) {
  assertthat::assert_that(
    base::is.character(vec_taxon_names),
    !base::anyNA(vec_taxon_names),
    base::all(base::nzchar(vec_taxon_names)),
    !base::anyDuplicated(vec_taxon_names),
    msg = stringr::str_c(
      "`vec_taxon_names` must be a character vector of unique names, ",
      "without missing or empty names."
    )
  )

  assertthat::assert_that(
    base::is.character(name_check_taxon),
    base::length(name_check_taxon) == 1L,
    !base::is.na(name_check_taxon),
    base::nzchar(name_check_taxon),
    msg = "`name_check_taxon` must be one taxon name."
  )

  assertthat::assert_that(
    base::is.character(sel_db_name),
    base::length(sel_db_name) == 1L,
    !base::is.na(sel_db_name),
    msg = "`sel_db_name` must be one name of a matching service."
  )

  assertthat::assert_that(
    base::is.character(sel_db_class),
    base::length(sel_db_class) == 1L,
    !base::is.na(sel_db_class),
    msg = "`sel_db_class` must be one name of a classification database."
  )

  assertthat::assert_that(
    base::is.logical(flag_only_exact_match),
    base::length(flag_only_exact_match) == 1L,
    !base::is.na(flag_only_exact_match),
    msg = "`flag_only_exact_match` must be TRUE or FALSE."
  )

  assertthat::assert_that(
    rlang::is_string(sel_kingdom),
    !base::is.na(sel_kingdom),
    msg = "`sel_kingdom` must be one name of a kingdom."
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  # The services treat letter case strictly: a name in capitals
  #   ("VACCINIUM VITIS-IDAEA") is not matched, and a capitalised second
  #   word ("Juglans Nigra") reaches only the genus. Names are sent with
  #   only their first letter in capitals; the result keeps them as written
  vec_written <-
    c(name_check_taxon, vec_taxon_names)

  vec_sentence <-
    stringr::str_c(
      stringr::str_to_upper(
        stringr::str_sub(string = vec_written, start = 1L, end = 1L)
      ),
      stringr::str_to_lower(
        stringr::str_sub(string = vec_written, start = 2L)
      )
    )

  name_check_query <-
    vec_sentence[1L]

  data_query <-
    tibble::tibble(
      taxon_name = vec_taxon_names,
      query_name = vec_sentence[-1L]
    )

  # The check name is classified with the batch, first; each name is sent
  #   once
  vec_query <-
    base::unique(vec_sentence)

  # taxospace stops the whole call when a name is matched to a taxon that
  #   GBIF does not have (for example "Spermatophyta Undiff(Shrubs)" is
  #   matched to "Spermatophyta"): its get_accepted_row() asserts a GBIF
  #   row. Only this error makes the batch be classified name by name, so
  #   that such a name stays unclassified; any other error stops the batch
  sel_empty_lookup <-
    "data_source must have at least one row"

  data_raw <-
    base::tryCatch(
      expr = taxospace::get_classification(
        taxa_vec = vec_query,
        sel_db_name = sel_db_name,
        sel_db_class = sel_db_class,
        use_only_exact_match = flag_only_exact_match,
        use_cache = FALSE,
        verbose = FALSE
      ) |>
        tibble::as_tibble() |>
        dplyr::mutate(
          dplyr::across(
            .cols = dplyr::any_of("id"),
            .fns = base::as.character
          )
        ),
      error = function(cnd) {
        if (
          !stringr::str_detect(
            string = base::conditionMessage(cnd),
            pattern = stringr::fixed(sel_empty_lookup)
          )
        ) {
          base::stop(cnd)
        }

        list_rows <-
          purrr::map(
            .x = vec_query,
            .f = ~ base::tryCatch(
              expr = taxospace::get_classification(
                taxa_vec = .x,
                sel_db_name = sel_db_name,
                sel_db_class = sel_db_class,
                use_only_exact_match = flag_only_exact_match,
                use_cache = FALSE,
                verbose = FALSE
              ) |>
                tibble::as_tibble() |>
                dplyr::mutate(
                  dplyr::across(
                    .cols = dplyr::any_of("id"),
                    .fns = base::as.character
                  )
                ),
              error = function(cnd_name) {
                if (
                  !stringr::str_detect(
                    string = base::conditionMessage(cnd_name),
                    pattern = stringr::fixed(sel_empty_lookup)
                  )
                ) {
                  base::stop(cnd_name)
                }

                NULL
              }
            )
          )

        # A name that fails alone gets an unclassified row
        vec_unlooked <-
          vec_query[purrr::map_lgl(.x = list_rows, .f = base::is.null)]

        data_rows <-
          dplyr::bind_rows(
            tibble::tibble(
              sel_name = base::character(0),
              id = base::character(0)
            ),
            list_rows,
            tibble::tibble(sel_name = vec_unlooked)
          )

        vec_classified <-
          data_rows |>
          dplyr::filter(!base::is.na(id)) |>
          dplyr::pull(sel_name)

        vec_unclassified <-
          base::setdiff(vec_query, vec_classified)

        cli::cli_warn(
          "taxospace stopped on a name matched to a taxon that GBIF does not
          have, so the batch was classified name by name;
          {base::length(vec_unclassified)} name{?s} stayed unclassified:
          {.val {vec_unclassified}}."
        )

        data_rows
      }
    )

  # A batch without any match has no `id` or `classification` column
  data_matched <-
    dplyr::bind_rows(
      tibble::tibble(
        sel_name = base::character(0),
        id = base::character(0),
        classification = base::list()
      ),
      dplyr::select(
        data_raw,
        dplyr::any_of(c("sel_name", "id", "classification"))
      )
    )

  # One GBIF taxon of the kingdom per name: the smallest id of equally good
  #   matches; a match to a taxon of another kingdom (an animal of the same
  #   name, for example) is dropped
  data_unnested <-
    data_matched |>
    dplyr::filter(!base::is.na(id)) |>
    dplyr::mutate(
      kingdom = purrr::map_chr(
        .x = classification,
        .f = ~ if (
          base::is.data.frame(.x)
        ) {
          dplyr::filter(.x, rank == "kingdom") |>
            dplyr::pull(name) |>
            purrr::pluck(1L, .default = NA_character_)
        } else {
          NA_character_
        }
      ),
      gbif_id = base::as.numeric(id)
    ) |>
    dplyr::filter(kingdom == sel_kingdom) |>
    dplyr::arrange(sel_name, gbif_id) |>
    dplyr::distinct(sel_name, .keep_all = TRUE) |>
    dplyr::select(sel_name, classification) |>
    tidyr::unnest(cols = classification)

  # The columns are given, because a batch without a match has none
  data_ranks <-
    dplyr::bind_rows(
      tibble::tibble(
        sel_name = base::character(0),
        name = base::character(0),
        rank = base::character(0)
      ),
      dplyr::select(
        data_unnested,
        dplyr::any_of(c("sel_name", "name", "rank"))
      )
    ) |>
    dplyr::filter(rank %in% c("species", "genus", "family")) |>
    # A GBIF placeholder species ("<genus> spec") is no species
    dplyr::filter(
      !(rank == "species" &
        stringr::str_detect(string = name, pattern = "\\sspec$"))
    ) |>
    dplyr::distinct(sel_name, rank, .keep_all = TRUE) |>
    dplyr::select(sel_name, rank, name)

  data_wide <-
    dplyr::bind_rows(
      tibble::tibble(
        sel_name = base::character(0),
        species = base::character(0),
        genus = base::character(0),
        family = base::character(0)
      ),
      tidyr::pivot_wider(
        data = data_ranks,
        names_from = rank,
        values_from = name
      )
    )

  vec_check_family <-
    data_wide |>
    dplyr::filter(sel_name == name_check_query) |>
    dplyr::pull(family)

  if (
    !base::any(!base::is.na(vec_check_family))
  ) {
    cli::cli_abort(
      c(
        "The check name {.val {name_check_taxon}} got no family, so the
        classification services did not answer; no result is kept.",
        "i" = "Run the classification again when the services work."
      )
    )
  }

  # Several written forms of a name ("Juglans Nigra", "JUGLANS NIGRA")
  #   share the classification of one query
  res <-
    data_query |>
    dplyr::left_join(
      dplyr::select(
        data_wide,
        query_name = sel_name,
        species_name = species,
        genus_name = genus,
        family_name = family
      ),
      by = dplyr::join_by(query_name),
      relationship = "many-to-one"
    ) |>
    dplyr::select(taxon_name, species_name, genus_name, family_name)

  if (
    base::isTRUE(verbose)
  ) {
    n_classified <-
      res |>
      dplyr::filter(
        !base::is.na(species_name) |
          !base::is.na(genus_name) |
          !base::is.na(family_name)
      ) |>
      base::nrow()

    cli::cli_inform(
      "Classification: {n_classified} of {base::nrow(res)} name{?s}
      classified."
    )
  }

  return(res)
}
