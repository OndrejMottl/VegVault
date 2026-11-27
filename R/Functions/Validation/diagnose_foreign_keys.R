#' @title Diagnose the foreign keys of a database
#' @description
#' Run SQLite's `foreign_key_check` once on a built VegVault database,
#' read-only, and report every child table with rows that have no parent
#' row.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `foreign_keys`: one `pass` row with scope `database` when every foreign
#' key has its parent row, otherwise one `fail` row per child and parent
#' table, with scope `<child> -> <parent>` and the number of rows without
#' a parent as the observed value.
#' @details
#' The assembly loads the tables with `foreign_keys = OFF`, so SQLite does
#' not enforce the declared foreign keys while writing; this check is the
#' only guard. `foreign_key_check` works whatever the `foreign_keys`
#' setting of the connection. Opens the database read-only. Aborts only
#' when the database is not the one of the manifest.
#' @examples
#' \dontrun{
#' diagnose_foreign_keys(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_foreign_keys <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  data_violations <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = "PRAGMA foreign_key_check",
      flag_read_only = TRUE
    )

  res <-
    if (
      base::nrow(data_violations) == 0L
    ) {
      build_check_result(
        check_id = "foreign_keys",
        scope = "database",
        status = "pass",
        observed = 0L,
        threshold = 0L,
        message = "Every foreign key has its parent row."
      )
    } else {
      data_counts <-
        data_violations |>
        dplyr::count(table, parent, name = "n_rows") |>
        dplyr::arrange(table, parent)

      build_check_result(
        check_id = "foreign_keys",
        scope = stringr::str_c(
          dplyr::pull(data_counts, table), " -> ",
          dplyr::pull(data_counts, parent)
        ),
        status = "fail",
        observed = dplyr::pull(data_counts, n_rows),
        threshold = 0L,
        message = stringr::str_c(
          dplyr::pull(data_counts, n_rows),
          base::ifelse(dplyr::pull(data_counts, n_rows) == 1L, " row", " rows"),
          " of ", dplyr::pull(data_counts, table),
          base::ifelse(dplyr::pull(data_counts, n_rows) == 1L, " has", " have"),
          " no parent row in ", dplyr::pull(data_counts, parent), "."
        )
      )
    }

  return(res)
}
