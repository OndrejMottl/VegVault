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
    paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  )


#----------------------------------------------------------#
# 2. Add empty tables -----
#----------------------------------------------------------#

# load the SQL query to make all tables
sql_query_full <-
  readLines(
    here::here(
      "Data/SQL/make_tables.sql"
    )
  )

# split the query by semicolon
sql_query_split <-
  paste(sql_query_full, collapse = "") %>%
  stringr::str_split(., pattern = "\\;") %>%
  unlist()

# execute each query
purrr::map(
  .x = sql_query_split,
  .f = ~ DBI::dbExecute(
    conn = con,
    statement = .x
  )
)

# check the db
DBI::dbListTables(con)
DBI::dbListObjects(con)

# disconnect
DBI::dbDisconnect(con)
