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
# Compatibility entry point for the legacy scripts
#   (R/02_Main_analyses/12_Export_db_flat.R, R/03_Visualisation/) and the
#   website, which source this file. It sources the project setup and
#   keeps the objects these scripts use. New code sources
#   R/___setup_project___.R directly. Remove this file when the website and
#   the legacy scripts move to the new setup, after the 2.0.0 release.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Loads the functions, attaches `packages: attach` of config.yml and
#   resolves the data root. Packages are restored from renv.lock by
#   R/___Init_project___.R, no longer here. The legacy scripts call every
#   other package with its namespace, so none is attached here
source(
  here::here("R/___setup_project___.R")
)

# The seed of the legacy scripts; the setup sets `seed` of config.yml
set.seed(1234)


#----------------------------------------------------------#
# 1. Database path -----
#----------------------------------------------------------#

# The database the legacy scripts and the website read and write: the
#   released v1 database, `database_v1_path` in the git-ignored
#   secrets.yaml, which replaces .secrets/path.yaml. The 2.0.0 build writes
#   `database_path` instead. Never run a legacy script that writes the
#   database without explicit authorization
path_to_vegvault <-
  resolve_database_path(key = "database_v1_path")


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
