#----------------------------------------------------------#
#
#
#                       VegVault
#
#           Build the reference counts of VegVault v1.0.0
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Write Data/Validation/v1.0.0_reference_counts.csv, the counts of the
#   released v1.0.0 database that the validation stage
#   (R/Analyses/04_Validation/) compares a build with, so that no run of
#   the stage opens the 110 GB v1.0.0 file (VegVault issue 96, decided by
#   Ondrej Mottl on 2026-11-21). The counts come from the saved results of
#   the read-only scans of v1.0.0:
#   - Documentation/Database_design_2.0.0_tables/q1_v1_content/, from
#     R/Analyses/90_Database_research/01_inspect_v1_metadata.R and
#     06_scan_v1_full.R;
#   - Data/Validation/v1.0.0_scan_per_source.csv, from
#     R/Validation/count_v1_per_source.R.
# Reads no database and is deterministic: rerunning it gives the same
#   file. Run from the repository root:
#   Rscript R/Validation/build_v1_reference_counts.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

path_output <-
  here::here("Data", "Validation", "v1.0.0_reference_counts.csv")


#----------------------------------------------------------#
# 1. Build and save -----
#----------------------------------------------------------#

data_reference <-
  build_v1_reference_counts()

base::dir.create(
  base::dirname(path_output),
  recursive = TRUE,
  showWarnings = FALSE
)

readr::write_csv(data_reference, path_output, na = "")

cli::cli_alert_success(
  "{base::nrow(data_reference)} reference counts in {.file {path_output}}."
)
