#' @title Validate that every trait record has its unit rules
#' @description
#' Check that every `conversion_rule_key` and `derivation_rule_key` of the
#' trait artefacts names a rule of the trait unit registry, so that the
#' database never stores a trait value whose conversion it cannot explain.
#' @param list_trait_artefacts
#' Named list by artefact id (for example `try_traits` and `bien_traits`)
#' of validated trait artefacts, each a named list of data frames as
#' returned by `load_producer_import()`, with the columns
#' `conversion_rule_key` and `derivation_rule_key`.
#' @param list_rules
#' Named list with the tibbles `unit_conversions` and `trait_derivations`,
#' as returned by `build_trait_unit_rules()`.
#' @return
#' Invisibly, a tibble with one row per artefact and rule column and the
#' columns `artefact_id`, `rule_column` (`"conversion_rule_key"` or
#' `"derivation_rule_key"`) and `n_keys` (integer: the distinct keys the
#' artefact cites).
#' @details
#' Missing keys are ignored: a record without a derivation has no
#' `derivation_rule_key`, and the trait contracts forbid a missing
#' `conversion_rule_key`. Only the two key columns of each table are read,
#' one table at a time, so a large artefact in several parts is never bound
#' into one table. Every missing rule is reported at once, with up to ten
#' keys per artefact and column, then the function aborts.
#' @seealso [build_trait_unit_rules()]
#' @examples
#' \dontrun{
#' validate_trait_rule_keys(
#'   list_trait_artefacts = list(
#'     try_traits = data_try_traits,
#'     bien_traits = data_bien_traits
#'   ),
#'   list_rules = data_trait_unit_rules
#' )
#' }
validate_trait_rule_keys <- function(
  list_trait_artefacts,
  list_rules
) {
  vec_rule_columns <-
    c("conversion_rule_key", "derivation_rule_key")

  flag_artefacts_valid <-
    base::is.list(list_trait_artefacts) &&
    !base::is.data.frame(list_trait_artefacts) &&
    base::length(list_trait_artefacts) > 0L &&
    !base::is.null(base::names(list_trait_artefacts)) &&
    base::all(
      purrr::map_lgl(
        .x = list_trait_artefacts,
        .f = ~ base::is.list(.x) &&
          !base::is.data.frame(.x) &&
          base::all(purrr::map_lgl(.x = .x, .f = base::is.data.frame))
      )
    )

  assertthat::assert_that(
    flag_artefacts_valid,
    msg = stringr::str_c(
      "`list_trait_artefacts` must be a named list of artefacts, each a ",
      "list of data frames."
    )
  )

  assertthat::assert_that(
    base::is.list(list_rules),
    !base::is.data.frame(list_rules),
    base::all(
      c("unit_conversions", "trait_derivations") %in% base::names(list_rules)
    ),
    msg = stringr::str_c(
      "`list_rules` must have `unit_conversions` and `trait_derivations` ",
      "(see build_trait_unit_rules())."
    )
  )

  list_keys_rules <-
    list(
      conversion_rule_key = list_rules |>
        purrr::chuck("unit_conversions") |>
        dplyr::pull(conversion_rule_key),
      derivation_rule_key = list_rules |>
        purrr::chuck("trait_derivations") |>
        dplyr::pull(derivation_rule_key)
    )

  # The distinct keys each artefact cites, read column by column and table
  #   by table
  data_keys <-
    tidyr::expand_grid(
      artefact_id = base::names(list_trait_artefacts),
      rule_column = vec_rule_columns
    ) |>
    dplyr::mutate(
      list_keys = purrr::map2(
        .x = artefact_id,
        .y = rule_column,
        .f = ~ {
          sel_column <- .y

          purrr::chuck(list_trait_artefacts, .x) |>
            purrr::map(
              .f = ~ {
                validate_data_columns(
                  data_source = .x,
                  vec_columns_required = sel_column,
                  name_argument = "list_trait_artefacts"
                )

                base::unique(.x[[sel_column]])
              }
            ) |>
            base::unlist(use.names = FALSE) |>
            base::unique() |>
            stats::na.omit() |>
            base::as.character()
        }
      ),
      n_keys = purrr::map_int(.x = list_keys, .f = base::length),
      list_missing = purrr::map2(
        .x = list_keys,
        .y = rule_column,
        .f = ~ base::setdiff(.x, purrr::chuck(list_keys_rules, .y))
      )
    )

  data_missing <-
    dplyr::filter(
      data_keys,
      purrr::map_int(.x = list_missing, .f = base::length) > 0L
    )

  if (
    base::nrow(data_missing) > 0L
  ) {
    vec_artefacts_missing <-
      dplyr::pull(data_missing, artefact_id)

    vec_columns_missing <-
      dplyr::pull(data_missing, rule_column)

    list_keys_missing <-
      dplyr::pull(data_missing, list_missing)

    # Keys may hold braces, which cli would read as glue expressions
    vec_problems <-
      purrr::map_chr(
        .x = base::seq_along(vec_artefacts_missing),
        .f = ~ stringr::str_c(
          vec_artefacts_missing[.x], ": ",
          base::length(list_keys_missing[[.x]]), " ",
          vec_columns_missing[.x], " value(s) without a rule: ",
          stringr::str_c(
            utils::head(list_keys_missing[[.x]], n = 10L),
            collapse = ", "
          ),
          "."
        )
      ) |>
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
        "Trait records cite unit rules that the trait unit registry lacks.",
        vec_problems
      )
    )
  }

  res <-
    dplyr::select(data_keys, artefact_id, rule_column, n_keys)

  return(invisible(res))
}
