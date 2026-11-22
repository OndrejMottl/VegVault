#' @title Prepare the fixed references of one source and role
#' @description
#' Return the references that `config.yml` gives a source for one role,
#' for example the citation of the source type, the reference of every
#' taxon of the source, or a general reference of the database.
#' @param list_source
#' Named list. One entry of `build: sources` in `config.yml`, with the
#' element `references`: a list of records, each with `role` (text),
#' `mandatory` (logical) and `detail` (the reference text).
#' @param sel_role
#' Character scalar. The role: `"source_type"`, or every `"data_source"`,
#' `"sampling_method"`, `"dataset"`, `"sample"`, `"taxon"`, `"trait"` or
#' `"abiotic_variable"` of the source, or `"general"` (a reference of the
#' database itself, linked to nothing).
#' @return
#' A tibble with the columns `reference_detail` (text) and `mandatory`
#' (logical), one row per reference of the role, possibly none.
#' @details
#' Aborts when `list_source` has no `references` element, when a record
#' lacks one of its three fields, has a role outside the nine above, a
#' `mandatory` that is not `TRUE` or `FALSE`, or an empty `detail`, or when
#' a role repeats a reference text.
#' @seealso [prepare_splot_tables()]
#' @examples
#' \dontrun{
#' data_taxon_references <-
#'   prepare_config_references(
#'     list_source = load_config_value(value = c("build", "sources", "try")),
#'     sel_role = "taxon"
#'   )
#' }
prepare_config_references <- function(
  list_source,
  sel_role
) {
  vec_roles <-
    c(
      "source_type", "data_source", "sampling_method", "dataset", "sample",
      "taxon", "trait", "abiotic_variable", "general"
    )

  assertthat::assert_that(
    base::is.character(sel_role),
    base::length(sel_role) == 1L,
    sel_role %in% vec_roles,
    msg = stringr::str_c(
      "`sel_role` must be one of ",
      stringr::str_c(vec_roles, collapse = ", "),
      "."
    )
  )

  assertthat::assert_that(
    base::is.list(list_source),
    "references" %in% base::names(list_source),
    base::is.list(purrr::chuck(list_source, "references")),
    msg = "`list_source` must hold a list of `references` records."
  )

  list_records <-
    purrr::chuck(list_source, "references")

  vec_complete <-
    purrr::map_lgl(
      .x = list_records,
      .f = ~ base::is.list(.x) &&
        base::all(c("role", "mandatory", "detail") %in% base::names(.x))
    )

  if (
    !base::all(vec_complete)
  ) {
    cli::cli_abort(
      "{base::sum(!vec_complete)} reference record{?s} of the source
      lack{?s/} {.field role}, {.field mandatory} or {.field detail}."
    )
  }

  data_records <-
    tibble::tibble(
      role = purrr::map_chr(
        .x = list_records,
        .f = ~ base::as.character(purrr::chuck(.x, "role"))
      ),
      mandatory = purrr::map(
        .x = list_records,
        .f = ~ purrr::chuck(.x, "mandatory")
      ),
      reference_detail = purrr::map(
        .x = list_records,
        .f = ~ purrr::chuck(.x, "detail")
      )
    )

  vec_unknown_roles <-
    base::setdiff(dplyr::pull(data_records, role), vec_roles)

  if (
    base::length(vec_unknown_roles) > 0L
  ) {
    cli::cli_abort(
      "Unknown reference role{?s} in the source: {.val {vec_unknown_roles}}."
    )
  }

  vec_flag_valid <-
    purrr::map_lgl(
      .x = dplyr::pull(data_records, mandatory),
      .f = ~ base::is.logical(.x) && base::length(.x) == 1L &&
        !base::is.na(.x)
    )

  if (
    !base::all(vec_flag_valid)
  ) {
    cli::cli_abort(
      "Every {.field mandatory} of a reference record must be TRUE or FALSE."
    )
  }

  vec_detail_valid <-
    purrr::map_lgl(
      .x = dplyr::pull(data_records, reference_detail),
      .f = ~ base::is.character(.x) && base::length(.x) == 1L &&
        !base::is.na(.x) && base::nzchar(.x)
    )

  if (
    !base::all(vec_detail_valid)
  ) {
    cli::cli_abort(
      "Every {.field detail} of a reference record must be a non-empty
      text."
    )
  }

  res <-
    data_records |>
    dplyr::mutate(
      mandatory = purrr::list_c(mandatory, ptype = base::logical()),
      reference_detail = purrr::list_c(
        reference_detail,
        ptype = base::character()
      )
    ) |>
    dplyr::filter(role == sel_role) |>
    dplyr::select(reference_detail, mandatory)

  if (
    base::anyDuplicated(dplyr::pull(res, reference_detail)) > 0L
  ) {
    cli::cli_abort(
      "A reference text repeats within the role {.val {sel_role}}."
    )
  }

  return(res)
}
