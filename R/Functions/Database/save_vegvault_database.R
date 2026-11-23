#' @title Save a VegVault database from tables prepared in memory
#' @description
#' Build the VegVault SQLite database at `path_database` from tables
#' prepared in memory: load them into a new work file next to it, finish
#' that file with `run_database_load()`, and move the result to
#' `path_database`. The database appears only when every step succeeded.
#' @param path_database
#' Character scalar. Path of the database to build, ending in `.sqlite`.
#' Never printed.
#' @param list_tables
#' Named list of data frames, named by schema table, with every id already
#' assigned (see `run_database_load()`).
#' @param list_pragmas_load
#' Named list. Settings of the load (see `run_database_load()`).
#' @param list_pragmas_final
#' Named list. Safe settings checked before `VACUUM INTO` (see
#' `run_database_load()`).
#' @param n_chunk_size
#' Whole number of at least 1. Rows per transaction.
#' @param flag_replace_existing
#' Logical scalar. If `FALSE` (default), abort before anything is written
#' when `path_database` exists. If `TRUE`, which is meant only for the
#' disposable database of the `subset` profile, replace it once the new
#' file is complete.
#' @param path_schema
#' Character scalar. Path of the schema file. Default:
#' `Data/SQL/make_tables.sql` of the project.
#' @param verbose
#' Logical. If `TRUE` (default), progress messages are printed via `cli`.
#' @return
#' Invisibly, the list returned by `run_database_load()`, with the step
#' `replace` added at the end of `data_steps`.
#' @details
#' The work and new files are those of `resolve_database_build_paths()`.
#' A work or new file left by a failed earlier build is removed first, so
#' a build always starts from an empty work file and never resumes. After
#' a failure the work file is left for inspection and `path_database` is
#' untouched. After success the work file is removed. `path_database` is
#' deleted only when `flag_replace_existing` is `TRUE`, and only after the
#' new file is complete. The folder of `path_database` must exist: it is
#' never created, so that a mistyped database path stops the build instead
#' of receiving a new database. Messages and errors name the roles of the
#' files, never their paths. The build manifest is written afterwards by
#' `save_build_manifest()`.
#' @seealso [run_database_load()], [resolve_database_build_paths()],
#' [save_build_manifest()]
#' @examples
#' \dontrun{
#' list_summary <-
#'   save_vegvault_database(
#'     path_database = resolve_database_path(),
#'     list_tables = list_tables,
#'     list_pragmas_load = load_config_value(
#'       value = c("build", "pragmas_load")
#'     ),
#'     list_pragmas_final = load_config_value(
#'       value = c("build", "pragmas_final")
#'     ),
#'     n_chunk_size = load_config_value(value = c("build", "chunk_size"))
#'   )
#' }
save_vegvault_database <- function(
  path_database,
  list_tables,
  list_pragmas_load,
  list_pragmas_final,
  n_chunk_size,
  flag_replace_existing = FALSE,
  path_schema = here::here("Data", "SQL", "make_tables.sql"),
  verbose = TRUE
) {
  assertthat::assert_that(
    base::is.character(path_database),
    base::length(path_database) == 1L,
    !base::is.na(path_database),
    base::nzchar(path_database),
    msg = "`path_database` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.list(list_tables),
    !base::is.data.frame(list_tables),
    msg = "`list_tables` must be a named list of data frames, one per table."
  )

  assertthat::assert_that(
    base::is.logical(flag_replace_existing),
    base::length(flag_replace_existing) == 1L,
    !base::is.na(flag_replace_existing),
    msg = "`flag_replace_existing` must be TRUE or FALSE."
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  # A missing folder stops the build, rather than being created: with the
  #   path of secrets.yaml, a mistyped folder would otherwise receive a new
  #   database. The message omits the path, because database paths are
  #   private
  if (
    !base::dir.exists(base::dirname(path_database))
  ) {
    cli::cli_abort(
      c(
        "The folder of the database does not exist, so nothing was built.",
        "i" = "Create the folder first, or correct the database path."
      )
    )
  }

  list_paths <-
    resolve_database_build_paths(path_database = path_database)

  path_work <-
    purrr::chuck(list_paths, "path_work")

  path_new <-
    purrr::chuck(list_paths, "path_new")

  if (
    base::file.exists(path_database) &&
      !base::isTRUE(flag_replace_existing)
  ) {
    cli::cli_abort(
      c(
        "The database file already exists, so nothing was built.",
        "i" = "Move or delete it by hand; the build never deletes a
        database unless it replaces the disposable subset database."
      )
    )
  }

  # Files an interrupted build may have left: the work file with its
  #   journal files, and an incomplete new file
  vec_leftovers <-
    c(
      path_work,
      stringr::str_c(path_work, c("-journal", "-wal", "-shm")),
      path_new
    )

  vec_leftovers_found <-
    vec_leftovers[base::file.exists(vec_leftovers)]

  if (
    base::length(vec_leftovers_found) > 0L
  ) {
    vec_removed <-
      base::file.remove(vec_leftovers_found)

    if (
      !base::all(vec_removed)
    ) {
      cli::cli_abort(
        "The files of an earlier build could not be removed; close any
        program that holds them and run the build again."
      )
    }

    if (
      base::isTRUE(verbose)
    ) {
      cli::cli_inform(
        "Removed {base::length(vec_leftovers_found)} file{?s} of an earlier
        build."
      )
    }
  }

  res_load <-
    run_with_database(
      path_database = path_work,
      fn = run_database_load,
      list_tables = list_tables,
      path_vacuum_into = path_new,
      list_pragmas_load = list_pragmas_load,
      list_pragmas_final = list_pragmas_final,
      n_chunk_size = n_chunk_size,
      path_schema = path_schema,
      verbose = verbose
    )

  time_replace_start <-
    base::proc.time()[["elapsed"]]

  # The database is replaced only now, when the new file is complete
  if (
    base::file.exists(path_database)
  ) {
    flag_old_removed <-
      base::file.remove(path_database)

    if (
      !base::isTRUE(flag_old_removed)
    ) {
      cli::cli_abort(
        "The disposable database could not be replaced; close any program
        that holds it. The new file is kept next to it."
      )
    }
  }

  flag_renamed <-
    base::file.rename(from = path_new, to = path_database)

  if (
    !base::isTRUE(flag_renamed)
  ) {
    cli::cli_abort(
      "The new file could not be moved to the database path."
    )
  }

  vec_work_files <-
    c(path_work, stringr::str_c(path_work, c("-journal", "-wal", "-shm")))

  vec_work_removed <-
    base::file.remove(vec_work_files[base::file.exists(vec_work_files)])

  if (
    !base::all(vec_work_removed)
  ) {
    cli::cli_warn(
      "The database was saved, but its work file could not be removed;
      delete it by hand."
    )
  }

  time_replace_end <-
    base::proc.time()[["elapsed"]]

  data_steps <-
    dplyr::bind_rows(
      purrr::chuck(res_load, "data_steps"),
      tibble::tibble(
        step = "replace",
        seconds = time_replace_end - time_replace_start
      )
    )

  if (
    base::isTRUE(verbose)
  ) {
    cli::cli_inform("Saved the database.")
  }

  res <-
    base::list(
      data_tables = purrr::chuck(res_load, "data_tables"),
      data_steps = data_steps
    )

  return(invisible(res))
}
