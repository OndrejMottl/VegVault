#----------------------------------------------------------#
#
#
#                       VegVault
#
#                     Config file
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#
# Compatibility entry point for the website, which sources this file
#   (directly and through R/Website/00_Config_quarto.R). It sources
#   the project setup and keeps the objects the website uses. New code
#   sources R/___setup_project___.R directly. Remove this file when the
#   website moves to the new setup, after the 2.0.0 release.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Loads the functions, attaches `packages: attach` of config.yml and
#   resolves the data root. Packages are restored from renv.lock by
#   R/___Init_project___.R, no longer here
source(
  here::here("R/___setup_project___.R")
)

# The seed of the website; the setup sets `seed` of config.yml
set.seed(1234)


#----------------------------------------------------------#
# 1. Database path -----
#----------------------------------------------------------#

# The database the website reads: the release database, `database_path`
#   in the git-ignored secrets.yaml
path_to_vegvault <-
  resolve_database_path(key = "database_path")

# Its build manifest must still describe the file (name, size and
#   modification time) and record a release build from a clean checkout,
#   so that the pages report the published database and nothing else
list_build_manifest <-
  load_build_manifest(
    path_manifest = resolve_build_manifest_path(
      path_database = path_to_vegvault
    ),
    path_database = path_to_vegvault,
    profile_expected = "release"
  )


#----------------------------------------------------------#
# 2. Database version -----
#----------------------------------------------------------#

# The version record of config.yml; its last entry is the version being
#   built
data_version_control <-
  load_config_value(value = c("database", "versions")) |>
  purrr::map(.f = tibble::as_tibble) |>
  dplyr::bind_rows() |>
  dplyr::mutate(
    # Checks the date format
    update_date = base::as.character(lubridate::ymd(update_date))
  )

db_version <-
  data_version_control |>
  dplyr::slice_tail(n = 1) |>
  dplyr::pull(version)

# The version the pages print must be the version the database records;
#   the two differ only when config.yml was changed after the build
version_manifest <-
  purrr::chuck(list_build_manifest, "version", "version")

if (
  !base::identical(base::as.character(version_manifest), db_version)
) {
  cli::cli_abort(
    c(
      "The database version in config.yml is not the one of the database.",
      "i" = "config.yml: {db_version}; build manifest: {version_manifest}."
    )
  )
}
