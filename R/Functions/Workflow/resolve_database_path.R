#' @title Resolve the path of a VegVault database
#' @description
#' Read the path of a VegVault SQLite database from the git-ignored,
#' machine-local `secrets.yaml`, so that no database path is written in
#' code or configuration.
#' @param key
#' Character scalar. Entry of `secrets.yaml` holding the path:
#' `"database_path"` (default) for the database being built, or
#' `"database_v1_path"` for the released v1.0.0 database used read-only
#' for comparisons.
#' @param path_secrets
#' Character scalar. Path of the secrets file.
#' @param path_project
#' Character scalar. Project root against which a relative path in the
#' secrets file is resolved.
#' @return
#' Character scalar. The absolute path of the database, with forward
#' slashes. The file does not need to exist, because a build creates it.
#' @details
#' Aborts when the secrets file is missing (create it from
#' `secrets_example.yaml`) or when `key` is absent or not a non-empty text
#' value. Error messages name the key and the secrets file but never the
#' path, because database paths are private.
#' @examples
#' \dontrun{
#' path_database <- resolve_database_path()
#' }
resolve_database_path <- function(
  key = "database_path",
  path_secrets = here::here("secrets.yaml"),
  path_project = here::here()
) {
  assertthat::assert_that(
    base::is.character(key),
    base::length(key) == 1L,
    !base::is.na(key),
    base::nzchar(key),
    msg = "`key` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.character(path_secrets),
    base::length(path_secrets) == 1L,
    base::is.character(path_project),
    base::length(path_project) == 1L,
    msg = "`path_secrets` and `path_project` must be character scalars."
  )

  if (
    !base::file.exists(path_secrets)
  ) {
    cli::cli_abort(
      c(
        "No secrets file {.file {base::basename(path_secrets)}} in the
        project.",
        "i" = "Create it from {.file secrets_example.yaml} and set
        {.field {key}}."
      )
    )
  }

  list_secrets <-
    yaml::read_yaml(file = path_secrets)

  value_path <-
    purrr::pluck(list_secrets, key)

  flag_valid <-
    base::is.character(value_path) &&
    base::length(value_path) == 1L &&
    !base::is.na(value_path) &&
    base::nzchar(value_path)

  # The message names the key only: database paths are private
  if (
    !flag_valid
  ) {
    cli::cli_abort(
      c(
        "{.field {key}} in {.file {base::basename(path_secrets)}} must be
        the path of the database as one text value.",
        "i" = "See {.file secrets_example.yaml}."
      )
    )
  }

  # A path that is not absolute is read from the project root
  path_full <-
    if (
      stringr::str_detect(value_path, "^([A-Za-z]:)?[/\\\\]")
    ) {
      value_path
    } else {
      base::file.path(path_project, value_path)
    }

  res <-
    base::normalizePath(path_full, winslash = "/", mustWork = FALSE)

  return(res)
}
