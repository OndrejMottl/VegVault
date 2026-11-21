#' @title Diagnose whether a database matches its schema file
#' @description
#' Compare a built VegVault database with its schema file, read-only, and
#' report the result as a row of the validation report instead of
#' aborting.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database (see
#' `validate_database_source()`).
#' @param path_schema
#' Character scalar. Path of the schema file. Default:
#' `Data/SQL/make_tables.sql` of the project.
#' @return
#' A tibble in the format of `build_check_result()` with one row, check
#' `schema` and scope `database`: `pass` when every table, view and index
#' of the schema file exists with its definition and the database has no
#' other object, `fail` otherwise, with the differences in the message.
#' @details
#' Runs `validate_database_schema()` with every index required, so a
#' database whose indexes were not created fails. Because the schema
#' enforces the keys, `NOT NULL`, `UNIQUE` and `CHECK` constraints, this one
#' row confirms that they exist; `integrity_check` then verifies them on
#' every row. Opens the database read-only. Aborts only when the database
#' is not the one of the manifest.
#' @examples
#' \dontrun{
#' diagnose_database_schema(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_database_schema <- function(
  path_database,
  list_build_manifest,
  path_schema = here::here("Data", "SQL", "make_tables.sql")
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  # A difference is a result of the check, not an error of the stage
  data_objects <-
    tryCatch(
      run_with_database(
        path_database = path_database,
        fn = validate_database_schema,
        path_schema = path_schema,
        flag_require_indexes = TRUE,
        flag_read_only = TRUE
      ),
      error = function(cnd) cnd
    )

  res <-
    if (
      rlang::is_condition(data_objects)
    ) {
      build_check_result(
        check_id = "schema",
        scope = "database",
        status = "fail",
        message = base::conditionMessage(data_objects) |>
          stringr::str_squish()
      )
    } else {
      build_check_result(
        check_id = "schema",
        scope = "database",
        status = "pass",
        observed = base::nrow(data_objects),
        threshold = base::nrow(data_objects),
        message = stringr::str_c(
          "The database holds the ", base::nrow(data_objects),
          " tables, views and indexes of the schema file, each as defined ",
          "there, and no other object."
        )
      )
    }

  return(res)
}
