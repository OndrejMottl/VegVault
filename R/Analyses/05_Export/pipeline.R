#----------------------------------------------------------#
#
#
#                         VegVault
#
#                     Export pipeline
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Defines the target graph of the export stage:
#   the flat-file export of the database.
#   Placeholder: no targets yet; the VegVault pipeline lane builds this stage
#   (see .ai/analysis-structure.md).
# Run with:
#   R/Analyses/05_Export/00_run.R
# Sourcing this script only declares targets; it does not execute them.


#----------------------------------------------------------#
# 0. Configure pipeline -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

targets::tar_option_set(
  seed = config_seed
)


#----------------------------------------------------------#
# 1. Upstream contract -----
#----------------------------------------------------------#

# None yet: list the imported public targets of upstream stores here


#----------------------------------------------------------#
# 2. Define targets -----
#----------------------------------------------------------#

list()
