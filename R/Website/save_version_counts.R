#----------------------------------------------------------#
#
#
#                       VegVault
#
#            Counts of a release for the changelog
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#
# Saves the counts of the release database that the changelog page of the
#   website reports, once per release, into
#   Data/Versions/<version>/database_counts.csv: the counts of the
#   comparison with v1.0.0 (compute_database_counts(): rows per table,
#   datasets, samples, positions, taxon records and trait values per
#   source, abiotic values per variable, links per sample) and the summary
#   statistics of the website (load_database_statistics(): tables, views,
#   columns, size, taxa without a classification, ...). The changelog
#   reads this file instead of the database, so that the section of a
#   release keeps its numbers when a later release replaces the database
#   the website reads. The database is opened read-only; an existing file
#   is not replaced. Run from the repository root once the release
#   database is built and accepted:
#
#   Rscript R/Website/save_version_counts.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# The release database (`path_to_vegvault`), its build manifest and the
#   version it records (`db_version`), checked against config.yml
source(
  here::here("R/00_Config_file.R")
)

flag_rewrite <- FALSE

path_output <-
  here::here("Data", "Versions", db_version, "database_counts.csv")

if (
  base::file.exists(path_output) && !flag_rewrite
) {
  cli::cli_abort(
    c(
      "The counts of VegVault {db_version} are saved already.",
      "i" = "Set `flag_rewrite` to TRUE to replace them."
    )
  )
}


#----------------------------------------------------------#
# 1. Count -----
#----------------------------------------------------------#

data_comparison_counts <-
  compute_database_counts(
    path_database = path_to_vegvault,
    list_build_manifest = list_build_manifest
  ) |>
  dplyr::transmute(
    metric,
    scope,
    n = n_v2
  )

data_statistics <-
  load_database_statistics(
    path_database = path_to_vegvault,
    list_build_manifest = list_build_manifest
  ) |>
  tidyr::pivot_longer(
    cols = tidyselect::everything(),
    names_to = "metric",
    values_to = "n"
  ) |>
  dplyr::mutate(scope = "database")

data_version_counts <-
  dplyr::bind_rows(data_comparison_counts, data_statistics) |>
  dplyr::mutate(version = db_version) |>
  dplyr::select("version", "metric", "scope", "n")


#----------------------------------------------------------#
# 2. Save -----
#----------------------------------------------------------#

base::dir.create(
  base::dirname(path_output),
  showWarnings = FALSE,
  recursive = TRUE
)

readr::write_csv(
  x = data_version_counts,
  file = path_output,
  na = ""
)

cli::cli_inform(
  "Saved {base::nrow(data_version_counts)} counts of VegVault {db_version}."
)
