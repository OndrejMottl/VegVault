#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#                     Make the database
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration
source(
  here::here(
    "R/00_Config_file.R"
  )
)

#----------------------------------------------------------#
# 1. Create a empty database -----
#----------------------------------------------------------#

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    here::here(
      "Data/SQL/VegVault.sqlite"
    )
  )

DBI::dbDisconnect(con)
