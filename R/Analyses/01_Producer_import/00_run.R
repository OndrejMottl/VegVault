#----------------------------------------------------------#
#
#
#                         VegVault
#
#                  Producer import stage
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Builds every pipeline of the producer import stage, each in its own
#   store under `<data root>/Targets_data/`.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

flag_visualise_pipeline <- FALSE


#----------------------------------------------------------#
# 1. Run pipelines -----
#----------------------------------------------------------#

run_target_pipeline(
  script = here::here("R/Analyses/01_Producer_import/pipeline.R"),
  store = resolve_pipeline_store_path(
    path_data_storage = path_data_storage,
    store_relative_path = "producer_import"
  ),
  visualise = flag_visualise_pipeline
)
