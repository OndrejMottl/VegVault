#----------------------------------------------------------#
#
#
#                       VegVault
#
#                     Project init
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#
# Prepare the reproducible R environment. Run once per checkout or
#   worktree from the project root in a fresh session:
#     Rscript R/___Init_project___.R
# The exact package versions of the lockfile are restored. Later snapshots
#   are a separate, deliberate maintenance step (see .ai/r-environment.md).
# This script uses base R only (plus renv), because it must run before any
#   project package is installed.


#----------------------------------------------------------#
# 0. Bootstrap renv -----
#----------------------------------------------------------#

if (
  isFALSE(requireNamespace("renv", quietly = TRUE))
) {
  message("Package {renv} is not installed; installing it from CRAN.")

  utils::install.packages(pkgs = "renv")
}

if (
  isFALSE(requireNamespace("renv", quietly = TRUE))
) {
  stop(
    "Package {renv} could not be installed; setup cannot continue.",
    call. = FALSE
  )
}


#----------------------------------------------------------#
# 1. Locate the project -----
#----------------------------------------------------------#

path_project <-
  normalizePath(
    path = ".",
    winslash = "/",
    mustWork = TRUE
  )

path_config <-
  file.path(path_project, "config.yml")

path_lockfile <-
  file.path(path_project, "renv.lock")

if (
  isFALSE(file.exists(path_config))
) {
  stop(
    "No config.yml in ",
    path_project,
    ". Run this script from the project root.",
    call. = FALSE
  )
}

if (
  isFALSE(file.exists(path_lockfile))
) {
  stop(
    "No lockfile at ",
    path_lockfile,
    ". Restore it from git before running this script.",
    call. = FALSE
  )
}


#----------------------------------------------------------#
# 2. Restore the locked packages -----
#----------------------------------------------------------#

message("Restoring the locked package versions.")

renv::restore(
  project = path_project,
  lockfile = path_lockfile,
  prompt = FALSE
)

message("Setup complete. Start scripts with R/___setup_project___.R.")
