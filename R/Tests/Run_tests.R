#----------------------------------------------------------#
#
#
#                       VegVault
#
#                    Run test suite
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#
# Checks the function-file contract, then runs every test in a clean R
#   subprocess. Exits with an error when any test fails or errors.
# Run with:
#   Rscript R/Tests/Run_tests.R
# For a focused run use `run_test_file()` after sourcing the setup.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)


#----------------------------------------------------------#
# 1. Validate function files -----
#----------------------------------------------------------#

# TODO: validate the whole of R/Functions/ once the legacy functions are
#   renamed to approved verbs during the template conversion. Until then
#   only the folders written to the template rules are checked; a folder
#   without function files yet is skipped
vec_dirs_checked <-
  here::here(
    "R", "Functions",
    c("Workflow", "Contracts", "Database", "Gridpoints")
  )

vec_dirs_with_files <-
  vec_dirs_checked[
    purrr::map_lgl(
      .x = vec_dirs_checked,
      .f = ~ base::length(
        base::list.files(path = .x, pattern = "[.]R$", recursive = TRUE)
      ) > 0L
    )
  ]

purrr::walk(
  .x = vec_dirs_with_files,
  .f = ~ validate_function_names(function_dir = .x)
)


#----------------------------------------------------------#
# 2. Run tests -----
#----------------------------------------------------------#

data_test_results <-
  run_project_tests()

n_failed <-
  data_test_results |>
  dplyr::pull("failed") |>
  base::sum()

n_errored <-
  data_test_results |>
  dplyr::pull("error") |>
  base::sum()

if (
  base::nrow(data_test_results) == 0L
) {
  cli::cli_abort("No tests were found or run.")
}

if (
  n_failed + n_errored > 0L
) {
  cli::cli_abort(
    "Test suite failed: {n_failed} failure{?s}, {n_errored} error{?s}."
  )
}

cli::cli_alert_success(
  "All {base::nrow(data_test_results)} tests passed."
)
