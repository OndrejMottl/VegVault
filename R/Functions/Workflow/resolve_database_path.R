#' @title Resolve the path of a VegVault database
#' @description
#' Return the path of a VegVault SQLite database. The live and v1.0.0
#' paths are read from the git-ignored, machine-local `secrets.yaml`, so
#' that they are never written in code or configuration. In the regional
#' `subset` profile, the database being built is instead a disposable file
#' under the data root, named in `config.yml`.
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
#' @param list_subset
#' Named list. The `subset` section of `config.yml`, with the logical
#' scalar `enabled` and, when enabled, the relative path `database_file`.
#' Default: the section of the active configuration profile.
#' @param path_data_storage
#' Character scalar. The data root under which `database_file` is
#' resolved. Default: the data root of the project, as resolved by
#' `resolve_data_storage_path()`; only evaluated when the subset is
#' enabled.
#' @return
#' Character scalar. The absolute path of the database, with forward
#' slashes. The file does not need to exist, because a build creates it.
#' @details
#' When the subset is enabled and `key` is `"database_path"`, the result is
#' `<path_data_storage>/<database_file>` and no database path is read from
#' the secrets file, so a regional rehearsal can never open the live
#' database. The secrets file is read only for the `Data` root, through the
#' default of `path_data_storage`. `database_file` must stay under the data
#' root (`validate_subset_database_file()`). The v1.0.0 path is always read
#' from the secrets file.
#' Otherwise, aborts when the secrets file is missing (create it from
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
  path_project = here::here(),
  list_subset = load_config_value(value = "subset"),
  path_data_storage = resolve_data_storage_path(
    path_default = load_config_value(value = "data_storage_path"),
    path_secrets = path_secrets,
    path_project = path_project
  )
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

  assertthat::assert_that(
    base::is.list(list_subset),
    msg = "`list_subset` must be the `subset` section of config.yml."
  )

  flag_subset <-
    purrr::pluck(list_subset, "enabled")

  if (
    !assertthat::is.flag(flag_subset) ||
      base::is.na(flag_subset)
  ) {
    cli::cli_abort(
      "{.field enabled} of the {.field subset} settings must be TRUE or
      FALSE."
    )
  }

  # A regional rehearsal builds a disposable database under the data root
  #   and never reads a database path from the secrets file, so it cannot
  #   open the live database
  if (
    key == "database_path" &&
      base::isTRUE(flag_subset)
  ) {
    database_file <-
      purrr::pluck(list_subset, "database_file")

    validate_subset_database_file(database_file = database_file)

    res_subset <-
      base::normalizePath(
        base::file.path(path_data_storage, database_file),
        winslash = "/",
        mustWork = FALSE
      )

    return(res_subset)
  }

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
