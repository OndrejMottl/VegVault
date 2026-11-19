#----------------------------------------------------------#
#
#
#                         VegVault
#
#                      Run all stages
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Runs the stage runners in order. Each stage builds its pipelines in their
#   own stores; up-to-date targets are skipped. Each runner sources the
#   project setup itself. Add every new stage runner to the list below.
# Run with:
#   Rscript R/Analyses/00_run_main.R
# The legacy script cascade R/01_Master.R stays until the stages replace
#   it; never run either against the live database without approval.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_stage_runners <-
  c(
    "R/Analyses/01_Producer_import/00_run.R",
    "R/Analyses/02_Gridpoints/00_run.R",
    "R/Analyses/03_Database_assembly/00_run.R",
    "R/Analyses/04_Validation/00_run.R",
    "R/Analyses/05_Export/00_run.R",
    "R/Analyses/06_Visualisation/00_run.R"
  )


#----------------------------------------------------------#
# 1. Run stages -----
#----------------------------------------------------------#

purrr::walk(
  .x = vec_stage_runners,
  .f = ~ base::source(
    file = here::here(.x)
  )
)
