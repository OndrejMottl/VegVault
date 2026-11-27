#' @title Diagnose repeated and missing names
#' @description
#' Check the name columns that the schema does not keep unique, in a built
#' VegVault database, read-only: taxon, trait, trait-domain and abiotic
#' variable names.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' A tibble in the format of `build_check_result()`, check `names`, with
#' one row per column, in this order: `Taxa.taxon_name`,
#' `Traits.trait_name`, `TraitsDomain.trait_domain_name` and
#' `AbioticVariable.abiotic_variable_name`. A row passes when every name
#' is present and occurs once; otherwise it is a `flag` with the number of
#' names that occur more than once as the observed value and the missing
#' names in the message.
#' @details
#' Sample and dataset names are `UNIQUE NOT NULL` in the schema, so
#' `integrity_check` covers them. These four columns are not, because their
#' duplicates were never measured; a `UNIQUE` constraint can follow once a
#' build shows none, and until then repeats are flagged for review, not
#' failed. Opens the database read-only. Aborts only when the database is
#' not the one of the manifest.
#' @examples
#' \dontrun{
#' diagnose_duplicate_names(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_duplicate_names <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  data_columns <-
    tibble::tibble(
      table = c("Taxa", "Traits", "TraitsDomain", "AbioticVariable"),
      column = c(
        "taxon_name", "trait_name", "trait_domain_name",
        "abiotic_variable_name"
      )
    ) |>
    dplyr::mutate(
      scope = stringr::str_c(table, ".", column),
      # Names that occur more than once, and missing names
      statement = stringr::str_c(
        "SELECT (SELECT COUNT(*) FROM (SELECT ", column, " FROM ", table,
        " WHERE ", column, " IS NOT NULL GROUP BY ", column,
        " HAVING COUNT(*) > 1)) AS n_repeated, ",
        "(SELECT COUNT(*) FROM ", table, " WHERE ", column,
        " IS NULL) AS n_missing"
      )
    )

  data_counts <-
    purrr::map(
      .x = dplyr::pull(data_columns, statement),
      .f = ~ run_with_database(
        path_database = path_database,
        fn = DBI::dbGetQuery,
        statement = .x,
        flag_read_only = TRUE
      )
    ) |>
    dplyr::bind_rows()

  data_result <-
    dplyr::bind_cols(data_columns, data_counts) |>
    dplyr::mutate(
      is_ok = n_repeated == 0L & n_missing == 0L,
      message = dplyr::if_else(
        is_ok,
        "Every name is present and occurs once.",
        stringr::str_c(
          "Names occurring more than once: ", n_repeated,
          "; missing names: ", n_missing, ". Flagged until a build shows ",
          "none, when a UNIQUE constraint can follow."
        )
      )
    )

  res <-
    build_check_result(
      check_id = "names",
      scope = dplyr::pull(data_result, scope),
      status = dplyr::if_else(dplyr::pull(data_result, is_ok), "pass", "flag"),
      observed = dplyr::pull(data_result, n_repeated),
      threshold = 0L,
      message = dplyr::pull(data_result, message)
    )

  return(res)
}
