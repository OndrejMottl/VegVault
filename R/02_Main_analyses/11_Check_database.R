#----------------------------------------------------------#
#
#
#                       VegVault
#
#                  Check the created DB
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Get classification for all taxa in the database

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

verbose <- FALSE


#----------------------------------------------------------#
# 1. Connect to db -----
#----------------------------------------------------------#

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_to_vegvault
  )


#----------------------------------------------------------#
# 2. Check connections within DB -----
#----------------------------------------------------------#

if (
  isTRUE(verbose)
) {
  # check the primary keys
  DBI::dbGetQuery(
    con,
    "
    SELECT m.name AS table_name, p.name AS column_name
    FROM sqlite_master m
    JOIN pragma_table_info(m.name) p
    WHERE p.pk > 0
    ORDER BY m.name, p.pk;
    "
  ) %>%
    View()

  # check all indexes
  DBI::dbGetQuery(
    con,
    "
    SELECT
      name AS index_name,
      tbl_name AS table_name,
      sql
    FROM
      sqlite_master
    WHERE
      type = 'index'
    ORDER BY
      tbl_name, index_name;
    "
  ) %>%
    View()
}


#----------------------------------------------------------#
# 3. Rebuild and compact the DB -----
#----------------------------------------------------------#

# WARNING! This will take a while

# Rebuild the database
DBI::dbExecute(
  con,
  "VACUUM;"
)

# Analyze the database
DBI::dbExecute(
  con,
  "ANALYZE;"
)

#----------------------------------------------------------#
# 4. Disconnect -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
