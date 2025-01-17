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

# add Author information
if (
  isTRUE(
    tbl(con, "Authors") %>%
      dplyr::collect() %>%
      nrow() == 0
  )
) {
  DBI::dbExecute(
    con,
    "
    INSERT INTO Authors (author_fullname, author_email, author_orcid)
    VALUES ('Ondřej Mottl', 'ondrej.mottl@gmail.com', '0000-0002-9796-5081');
    "
  )
}

# update the database version
db_version_control <-
  dplyr::tbl(
    con, "version_control"
  ) %>%
  dplyr::collect()

update_db_version <- FALSE

if (
  nrow(db_version_control) == 0
) {
  add_to_db(
    conn = con,
    data = data_version_control,
    table_name = "version_control"
  )
} else {
  if (
    db_version_control %>%
      dplyr::slice_tail(n = 1) %>%
      purrr::chuck("version") !=
      db_version # [config]
  ) {
    update_db_version <- TRUE
  }
}

if (
  isTRUE(update_db_version)
) {
  DBI::dbExecute(
    con,
    paste0(
      "INSERT INTO version_control (version, changelog)",
      "VALUES ('",
      db_version, # [config]
      "', '');"
    )
  )
}

# general reference of the database
add_to_db(
  conn = con,
  data = tibble::tibble(
    reference_detail = "VegVault: an interdisciplinary database linking paleo-, and neo-vegetation data with functional traits and abiotic drivers",
    mandatory = TRUE,
  ),
  table_name = "References"
)

# disconnect
DBI::dbDisconnect(con)
