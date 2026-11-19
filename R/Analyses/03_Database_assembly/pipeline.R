#----------------------------------------------------------#
#
#
#                         VegVault
#
#                Database assembly pipeline
#
#
#                         O. Mottl
#                           2026
#
#----------------------------------------------------------#
# Defines the target graph of the database assembly stage:
#   the SQLite schema, table assembly and writes.
#   Placeholder: no targets yet; the database-core lane builds this stage
#   (see .ai/analysis-structure.md).
# Run with:
#   R/Analyses/03_Database_assembly/00_run.R
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
