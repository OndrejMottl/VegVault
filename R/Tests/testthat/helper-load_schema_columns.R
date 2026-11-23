# Read the column names of one table of the database schema
#   (Data/SQL/make_tables.sql), without its id column
#   (<table in snake case>_id), in the order of the schema.
load_schema_columns <- function(name_table) {
  vec_lines <-
    base::readLines(here::here("Data", "SQL", "make_tables.sql"))

  index_start <-
    base::which(
      vec_lines == stringr::str_c('CREATE TABLE "', name_table, '"')
    )

  vec_ends <-
    base::which(stringr::str_detect(vec_lines, "^\\);"))

  index_end <-
    vec_ends[vec_ends > index_start][1]

  name_id <-
    name_table |>
    stringr::str_replace_all("([a-z])([A-Z])", "\\1_\\2") |>
    stringr::str_to_lower() |>
    stringr::str_c("_id")

  mat_match <-
    stringr::str_match(
      vec_lines[index_start:index_end],
      '^\\s+"([a-z_]+)"'
    )

  vec_columns <-
    mat_match[, 2]

  res <-
    vec_columns[!base::is.na(vec_columns)] |>
    base::setdiff(name_id)

  return(res)
}
