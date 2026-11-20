#' @title Validate the relations between the FOSSILPOL artefacts
#' @description
#' Check the `relations` of the FOSSILPOL contracts, which the contract
#' validator does not evaluate because they link two artefacts or two
#' list-columns: the age-uncertainty iterations and the data assembly hold
#' the same datasets, the iterations of a dataset are named by the samples
#' of its levels, and the levels and counts of a dataset have the same
#' samples.
#' @param list_assembly
#' Named list of data frames: the validated `fossilpol_assembly` artefact,
#' with `dataset_id` and the list-columns `levels` and `counts_harmonised`
#' (data frames with `sample_id`).
#' @param list_age_uncertainty
#' Named list of data frames: the validated `fossilpol_age_uncertainty`
#' artefact, with `dataset_id` and the list-column `age_uncertainty`
#' (matrices whose column names are sample IDs).
#' @return
#' Invisibly, a tibble with one row per relation and the columns `relation`
#' (character) and `n_datasets` (integer: the datasets checked).
#' @details
#' Dataset IDs are compared as text and must not repeat within an
#' artefact. Sample IDs are compared as sets, so their order does not
#' matter. Every broken relation is reported at once,
#' with up to five dataset IDs each, then the function aborts. The
#' relations hold for every dataset of the v1 artefacts.
#' @examples
#' \dontrun{
#' validate_fossilpol_relations(
#'   list_assembly = data_fossilpol_assembly,
#'   list_age_uncertainty = data_fossilpol_age_uncertainty
#' )
#' }
validate_fossilpol_relations <- function(
  list_assembly,
  list_age_uncertainty
) {
  assertthat::assert_that(
    base::is.list(list_assembly),
    !base::is.data.frame(list_assembly),
    base::all(purrr::map_lgl(.x = list_assembly, .f = base::is.data.frame)),
    msg = "`list_assembly` must be a list of data frames."
  )

  assertthat::assert_that(
    base::is.list(list_age_uncertainty),
    !base::is.data.frame(list_age_uncertainty),
    base::all(
      purrr::map_lgl(.x = list_age_uncertainty, .f = base::is.data.frame)
    ),
    msg = "`list_age_uncertainty` must be a list of data frames."
  )

  data_assembly <-
    dplyr::bind_rows(list_assembly)

  data_age <-
    dplyr::bind_rows(list_age_uncertainty)

  validate_data_columns(
    data_source = data_assembly,
    vec_columns_required = c("dataset_id", "levels", "counts_harmonised"),
    name_argument = "list_assembly"
  )

  validate_data_columns(
    data_source = data_age,
    vec_columns_required = c("dataset_id", "age_uncertainty"),
    name_argument = "list_age_uncertainty"
  )

  vec_ids_assembly <-
    dplyr::pull(data_assembly, dataset_id) |>
    base::as.character()

  vec_ids_age <-
    dplyr::pull(data_age, dataset_id) |>
    base::as.character()

  #--------------------------------------------------#
  ## Sample IDs per dataset -----
  #--------------------------------------------------#

  list_samples_levels <-
    dplyr::pull(data_assembly, levels) |>
    purrr::map(.f = ~ dplyr::pull(.x, sample_id)) |>
    rlang::set_names(vec_ids_assembly)

  list_samples_counts <-
    dplyr::pull(data_assembly, counts_harmonised) |>
    purrr::map(.f = ~ dplyr::pull(.x, sample_id)) |>
    rlang::set_names(vec_ids_assembly)

  list_samples_age <-
    dplyr::pull(data_age, age_uncertainty) |>
    purrr::map(.f = base::colnames) |>
    rlang::set_names(vec_ids_age)

  vec_ids_matched <-
    base::intersect(vec_ids_age, vec_ids_assembly)

  # A repeated dataset would be compared on its first row only
  vec_ids_repeated_assembly <-
    vec_ids_assembly[base::duplicated(vec_ids_assembly)] |>
    base::unique()

  vec_ids_repeated_age <-
    vec_ids_age[base::duplicated(vec_ids_age)] |>
    base::unique()

  #--------------------------------------------------#
  ## Broken relations -----
  #--------------------------------------------------#

  vec_ids_not_in_assembly <-
    base::setdiff(vec_ids_age, vec_ids_assembly)

  vec_ids_without_age <-
    base::setdiff(vec_ids_assembly, vec_ids_age)

  vec_ids_age_differs <-
    vec_ids_matched[
      !purrr::map_lgl(
        .x = vec_ids_matched,
        .f = ~ base::setequal(
          purrr::chuck(list_samples_age, .x),
          purrr::chuck(list_samples_levels, .x)
        )
      )
    ]

  vec_ids_counts_differ <-
    vec_ids_assembly[
      !purrr::map2_lgl(
        .x = list_samples_levels,
        .y = list_samples_counts,
        .f = base::setequal
      )
    ]

  list_broken <-
    list(
      "{n} dataset ID{?s} {?is/are} repeated in the assembly: " =
        vec_ids_repeated_assembly,
      "{n} dataset ID{?s} {?is/are} repeated in the age uncertainty: " =
        vec_ids_repeated_age,
      "{n} age-uncertainty dataset{?s} {?is/are} not in the assembly: " =
        vec_ids_not_in_assembly,
      "{n} assembly dataset{?s} {?has/have} no age-uncertainty row: " =
        vec_ids_without_age,
      "{n} dataset{?s} {?has/have} iterations not named by the samples of
        its levels: " = vec_ids_age_differs,
      "{n} dataset{?s} {?has/have} different samples in the levels and
        counts: " = vec_ids_counts_differ
    )

  vec_problems <-
    purrr::imap(
      .x = list_broken,
      .f = ~ {
        n <-
          base::length(.x)

        if (
          n > 0L
        ) {
          stringr::str_c(
            cli::pluralize(stringr::str_squish(.y)),
            " ",
            stringr::str_flatten(utils::head(.x, 5L), collapse = ", "),
            if (
              n > 5L
            ) {
              ", ..."
            },
            "."
          )
        }
      }
    ) |>
    base::unlist(use.names = FALSE)

  if (
    base::length(vec_problems) > 0L
  ) {
    # Dataset IDs could hold braces, which cli would read as expressions
    vec_problems_escaped <-
      vec_problems |>
      stringr::str_replace_all(
        pattern = stringr::fixed("{"),
        replacement = "{{"
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed("}"),
        replacement = "}}"
      ) |>
      rlang::set_names("x")

    cli::cli_abort(
      c(
        "The relations of the FOSSILPOL artefacts do not hold.",
        vec_problems_escaped
      )
    )
  }

  res <-
    tibble::tibble(
      relation = c(
        "same datasets in the assembly and the age uncertainty",
        "iterations named by the samples of the levels",
        "same samples in the levels and the counts"
      ),
      n_datasets = c(
        base::length(base::union(vec_ids_assembly, vec_ids_age)),
        base::length(vec_ids_matched),
        base::length(vec_ids_assembly)
      )
    )

  return(invisible(res))
}
