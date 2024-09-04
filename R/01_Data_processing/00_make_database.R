#----------------------------------------------------------#
#
#
#                       VegVault
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
    path_to_vegvault
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
try(
  purrr::map(
    .x = sql_query_split,
    .f = ~ DBI::dbExecute(
      conn = con,
      statement = .x
    )
  ),
  silent = TRUE
)

# check the db
DBI::dbListTables(con)
DBI::dbListObjects(con)

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
)

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
)

# disconnect
DBI::dbDisconnect(con)
