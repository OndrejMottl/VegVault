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
#' cache files of similar names share a file name. When a name matches
#' several GBIF taxa equally well, the taxon with the smallest GBIF id is
#' used, as in v1.0.0. A rank is the first name of that rank in the
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
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  # The check name is classified with the batch, first
  vec_query <-
    base::union(name_check_taxon, vec_taxon_names)

  data_raw <-
    taxospace::get_classification(
      taxa_vec = vec_query,
      sel_db_name = sel_db_name,
      sel_db_class = sel_db_class,
      use_cache = FALSE,
      verbose = FALSE
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      dplyr::across(
        .cols = dplyr::any_of("id"),
        .fns = base::as.character
      )
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

  # One GBIF taxon per name: the smallest id of equally good matches
  data_unnested <-
    data_matched |>
    dplyr::filter(!base::is.na(id)) |>
    dplyr::mutate(gbif_id = base::as.numeric(id)) |>
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
    dplyr::filter(sel_name == name_check_taxon) |>
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

  res <-
    tibble::tibble(taxon_name = vec_taxon_names) |>
    dplyr::left_join(
      dplyr::select(
        data_wide,
        taxon_name = sel_name,
        species_name = species,
        genus_name = genus,
        family_name = family
      ),
      by = dplyr::join_by(taxon_name),
      relationship = "one-to-one"
    )

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
