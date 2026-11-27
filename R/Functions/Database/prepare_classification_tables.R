#' @title Prepare the tables of the taxon classification
#' @description
#' Turn the classification of the taxon names into the source tables of
#' `build_source_table_template()`: the classification of every
#' classified name, and the species, genera and families it names, as
#' taxa with the classification reference and with their own
#' classification, as the v1.0.0 classification step did.
#' @param data_classification
#' A data frame with `taxon_name`, `species_name`, `genus_name` and
#' `family_name`, one row per taxon name of the sources (see
#' `classify_taxa()`).
#' @param list_source
#' Named list. The `build: sources: taxospace` entry of `config.yml`, with
#' `references`.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' A named list of tibbles with the elements and columns of
#' `build_source_table_template()`; only `taxa`, `taxon_references` and
#' `taxon_classification` have rows.
#' @details
#' A name with at least one of the three ranks gets a classification row;
#' a name with none gets no row, as in v1.0.0. Every species, genus and
#' family name becomes a taxon with the `taxon` references of
#' `list_source` (the reference `taxospace` in v1.0.0), also when it is a
#' taxon of a source.
#'
#' A species, genus or family name that is not itself a classified name
#' gets the classification its rank gives: a species the genus and family
#' of the names it classifies, a genus its family, and a family only
#' itself. When the names give different ranks (homonyms), the
#' classification most names give is used, then the first in C-locale
#' order. v1.0.0 classified these names online again instead; here they
#' need no second query, so a genus cannot be matched to a homonym in
#' another kingdom.
#' Aborts when a column or field is missing or a taxon name repeats.
#' @seealso [classify_taxa()], [build_database_tables()]
#' @examples
#' \dontrun{
#' list_classification_tables <-
#'   prepare_classification_tables(
#'     data_classification = data_classification,
#'     list_source = load_config_value(
#'       value = c("build", "sources", "taxospace")
#'     )
#'   )
#' }
prepare_classification_tables <- function(
  data_classification,
  list_source,
  verbose = TRUE
) {
  vec_required <-
    c("taxon_name", "species_name", "genus_name", "family_name")

  assertthat::assert_that(
    base::is.data.frame(data_classification),
    msg = "`data_classification` must be a data frame."
  )

  vec_absent <-
    base::setdiff(vec_required, base::names(data_classification))

  assertthat::assert_that(
    base::length(vec_absent) == 0L,
    msg = stringr::str_c(
      "`data_classification` lacks the columns: ",
      stringr::str_c(vec_absent, collapse = ", ")
    )
  )

  assertthat::assert_that(
    base::is.list(list_source),
    "references" %in% base::names(list_source),
    msg = "`list_source` lacks the field: references"
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  data_input <-
    data_classification |>
    dplyr::select(dplyr::all_of(vec_required)) |>
    dplyr::mutate(
      dplyr::across(
        .cols = dplyr::everything(),
        .fns = base::as.character
      )
    )

  vec_input_names <-
    dplyr::pull(data_input, taxon_name)

  vec_repeated <-
    base::unique(vec_input_names[base::duplicated(vec_input_names)])

  if (
    base::length(vec_repeated) > 0L
  ) {
    cli::cli_abort(
      "{base::length(vec_repeated)} taxon name{?s} with more than one
      classification: {.val {utils::head(vec_repeated, 5L)}}."
    )
  }

  # A name with at least one rank is classified
  data_classified <-
    data_input |>
    dplyr::filter(
      !base::is.na(species_name) |
        !base::is.na(genus_name) |
        !base::is.na(family_name)
    )

  vec_classified_names <-
    dplyr::pull(data_classified, taxon_name)

  # Each rank name with the ranks above it, once per name that gives it
  data_candidates <-
    dplyr::bind_rows(
      data_classified |>
        dplyr::filter(!base::is.na(species_name)) |>
        dplyr::mutate(taxon_name = species_name),
      data_classified |>
        dplyr::filter(!base::is.na(genus_name)) |>
        dplyr::mutate(
          taxon_name = genus_name,
          species_name = NA_character_
        ),
      data_classified |>
        dplyr::filter(!base::is.na(family_name)) |>
        dplyr::mutate(
          taxon_name = family_name,
          species_name = NA_character_,
          genus_name = NA_character_
        )
    )

  data_candidate_counts <-
    data_candidates |>
    dplyr::filter(!taxon_name %in% vec_classified_names) |>
    dplyr::count(taxon_name, species_name, genus_name, family_name)

  vec_homonyms <-
    data_candidate_counts |>
    dplyr::count(taxon_name, name = "n_candidates") |>
    dplyr::filter(n_candidates > 1L) |>
    dplyr::pull(taxon_name)

  # The classification most names give, then the first in C-locale order
  data_rank_rows <-
    data_candidate_counts |>
    dplyr::arrange(
      taxon_name, dplyr::desc(n), species_name, genus_name, family_name,
      .locale = "C"
    ) |>
    dplyr::distinct(taxon_name, .keep_all = TRUE) |>
    dplyr::select(dplyr::all_of(vec_required))

  data_rank_names <-
    tibble::tibble(
      taxon_name = c(
        dplyr::pull(data_classified, species_name),
        dplyr::pull(data_classified, genus_name),
        dplyr::pull(data_classified, family_name)
      )
    ) |>
    dplyr::filter(!base::is.na(taxon_name)) |>
    dplyr::distinct(taxon_name) |>
    dplyr::arrange(taxon_name, .locale = "C")

  list_tables <-
    base::list(
      taxa = data_rank_names,
      taxon_references = dplyr::cross_join(
        data_rank_names,
        prepare_config_references(
          list_source = list_source,
          sel_role = "taxon"
        )
      ),
      taxon_classification = dplyr::bind_rows(
        data_classified,
        data_rank_rows
      ) |>
        dplyr::arrange(taxon_name, .locale = "C")
    )

  # Every element of the template, with its columns and types
  res <-
    build_source_table_template() |>
    purrr::imap(
      .f = ~ dplyr::bind_rows(.x, purrr::pluck(list_tables, .y))
    )

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform(
      c(
        "Classification: {base::length(vec_classified_names)} of
        {base::nrow(data_input)} taxon name{?s} classified;
        {base::nrow(data_rank_names)} species, genus and family name{?s},
        {base::nrow(data_rank_rows)} of them classified by rank.",
        "i" = "{base::length(vec_homonyms)} rank name{?s} with differing
        ranks above {?it/them}."
      )
    )
  }

  return(res)
}
