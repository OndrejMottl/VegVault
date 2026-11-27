#' @title Diagnose the trait value rows against the pinned records
#' @description
#' Check that every record of each pinned trait artefact became exactly one
#' `TraitsValue` row of the built database: the rows of each trait source
#' must equal the row count that stage 01 recorded in the artefact's pin.
#' @param data_counts
#' A tibble of counts of the database, as returned by
#' `compute_database_counts()`, with `metric`, `scope` and `n_v2`; the rows
#' of metric `traits_value_rows` are used.
#' @param list_build_manifest
#' Named list. The build manifest of the database, as returned by
#' `load_build_manifest()`, whose `producer_pins` carry `n_rows`.
#' @param list_sources
#' Named list or named character vector, the section
#' `validation: trait_value_counts` of `config.yml`: per trait artefact id
#' the scope of its rows in `data_counts`, for example
#' `try_traits = "traits / TRY"`.
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `trait_value_counts`: one row per source, in the order of
#' `list_sources`, with the database rows as the observed value and the
#' pinned records as the threshold, then one `fail` row per other scope of
#' `traits_value_rows`, sorted. A source passes when the two are equal.
#' @details
#' The database assembly turns every record it receives into one
#' `TraitsValue` row and stops rather than drop one, and stage 01 counts the
#' records after the subset cut (`compute_artefact_rows()`), so the two
#' numbers must be equal in every profile. A source without rows in the
#' database counts 0. A source fails when its artefact is not pinned, when
#' its pin has no `n_rows` (a manifest written before stage 01 counted the
#' rows), or when the numbers differ. Rows of a scope that no source names,
#' for example trait datasets without a source type, fail, because no pin
#' can account for them. Reads no database: `data_counts` holds the counts,
#' grouped through `TraitsValue.dataset_id`.
#' @seealso [compute_database_counts()], [compute_artefact_rows()]
#' @examples
#' \dontrun{
#' diagnose_trait_value_counts(
#'   data_counts = data_database_counts,
#'   list_build_manifest = list_build_manifest,
#'   list_sources = load_config_value(
#'     value = c("validation", "trait_value_counts")
#'   )
#' )
#' }
diagnose_trait_value_counts <- function(
  data_counts,
  list_build_manifest,
  list_sources
) {
  validate_data_columns(
    data_source = data_counts,
    vec_columns_required = c("metric", "scope", "n_v2"),
    name_argument = "data_counts"
  )

  vec_artefact_ids <-
    base::names(list_sources)

  assertthat::assert_that(
    base::length(list_sources) > 0L,
    !base::is.null(vec_artefact_ids),
    base::all(base::nzchar(vec_artefact_ids)),
    !base::anyDuplicated(vec_artefact_ids),
    base::all(
      purrr::map_lgl(
        .x = list_sources,
        .f = ~ base::is.character(.x) && base::length(.x) == 1L &&
          !base::is.na(.x)
      )
    ),
    msg = stringr::str_c(
      "`list_sources` must name one scope (text) per trait artefact id."
    )
  )

  vec_scopes <-
    purrr::map_chr(.x = list_sources, .f = ~ .x)

  list_pins <-
    purrr::pluck(list_build_manifest, "producer_pins", .default = list())

  vec_pinned_ids <-
    purrr::map_chr(.x = list_pins, .f = ~ purrr::chuck(.x, "artefact_id"))

  # The pinned records per source; NA when the pin or its count is missing
  vec_n_pinned <-
    purrr::map_dbl(
      .x = vec_artefact_ids,
      .f = ~ {
        index_pin <- base::match(.x, vec_pinned_ids)

        if (
          base::is.na(index_pin)
        ) {
          NA_real_
        } else {
          base::as.numeric(
            purrr::pluck(list_pins, index_pin, "n_rows", .default = NA)
          )
        }
      }
    )

  vec_is_pinned <-
    vec_artefact_ids %in% vec_pinned_ids

  data_rows <-
    dplyr::filter(data_counts, metric == "traits_value_rows")

  vec_n_database <-
    dplyr::pull(data_rows, n_v2)[
      base::match(vec_scopes, dplyr::pull(data_rows, scope))
    ] |>
    dplyr::coalesce(0)

  vec_status <-
    dplyr::if_else(
      vec_is_pinned & !base::is.na(vec_n_pinned) &
        vec_n_pinned == vec_n_database,
      "pass",
      "fail"
    )

  vec_messages <-
    dplyr::case_when(
      !vec_is_pinned ~ stringr::str_c(
        vec_artefact_ids, " is not pinned in the build manifest, so its ",
        vec_n_database, " TraitsValue row(s) of ", vec_scopes,
        " cannot be checked."
      ),
      base::is.na(vec_n_pinned) ~ stringr::str_c(
        "The pin of ", vec_artefact_ids, " has no row count; run stage 01 ",
        "again so that the build manifest records it."
      ),
      vec_status == "pass" ~ stringr::str_c(
        "TraitsValue rows of ", vec_scopes, ": ", vec_n_database,
        ", one per record of the pinned ", vec_artefact_ids, "."
      ),
      .default = stringr::str_c(
        "TraitsValue rows of ", vec_scopes, ": ", vec_n_database,
        ", but the pinned ", vec_artefact_ids, " has ", vec_n_pinned,
        " records; every record must become one row."
      )
    )

  data_sources <-
    build_check_result(
      check_id = "trait_value_counts",
      scope = base::unname(vec_scopes),
      status = vec_status,
      observed = vec_n_database,
      threshold = vec_n_pinned,
      message = vec_messages
    )

  # Rows of scopes that no source names
  data_unknown <-
    data_rows |>
    dplyr::filter(!scope %in% vec_scopes) |>
    dplyr::arrange(scope)

  res <-
    if (
      base::nrow(data_unknown) == 0L
    ) {
      data_sources
    } else {
      dplyr::bind_rows(
        data_sources,
        build_check_result(
          check_id = "trait_value_counts",
          scope = dplyr::pull(data_unknown, scope),
          status = "fail",
          observed = dplyr::pull(data_unknown, n_v2),
          threshold = 0,
          message = stringr::str_c(
            dplyr::pull(data_unknown, n_v2), " TraitsValue row(s) of ",
            dplyr::pull(data_unknown, scope), ", a source that no pinned ",
            "trait artefact accounts for."
          )
        )
      )
    }

  return(res)
}
