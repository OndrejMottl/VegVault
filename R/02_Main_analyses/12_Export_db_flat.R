#----------------------------------------------------------#
#
#
#                       VegVault
#
#                Export DB as flat files
#
#
#                       O. Mottl
#                         2025
#
#----------------------------------------------------------#

# Export all tables in the VegVault database as flat files.

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

rewrite <- FALSE


#----------------------------------------------------------#
# 1. Connect to db -----
#----------------------------------------------------------#

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_to_vegvault
  )


#----------------------------------------------------------#
# 2. make a list of all tables -----
#----------------------------------------------------------#

vec_db_tables <-
  DBI::dbListTables(con)


#----------------------------------------------------------#
# 3. Save all tables as CSV files -----
#----------------------------------------------------------#

# for each table, export it as a CSV file

# Path to sqlite3 executable
sqlite_path <- Sys.which("sqlite3")

vec_db_tables %>%
  purrr::walk(
    .progress = "Exporting VegVault tables",
    .f = ~ {
      csv_path <-
        here::here(
          "Outputs/Data/VegVault/Flat_files",
          paste0(.x, ".csv")
        )

      message(
        paste(
          "Exporting table",
          .x,
          "to",
          csv_path
        )
      )

      if (
        isFALSE(rewrite) && file.exists(csv_path)
      ) {
        return()
      }

      # Compose the SQLite export command
      cmd <-
        sprintf(
          '"%s" "%s" ".headers on" ".mode csv" ".once %s" "SELECT * FROM [%s];"',
          sqlite_path,
          here::here("Outputs/Data/VegVault/VegVault.sqlite"),
          csv_path,
          .x
        )

      # Run the command
      system(cmd)
    }
  )


#----------------------------------------------------------#
# 4. Export column names and types -----
#----------------------------------------------------------#

# For each table, export the column names and types to a CSV file

vec_db_tables %>%
  purrr::set_names() %>%
  purrr::map(
    .progress = "Exporting VegVault table column names and types",
    .f = ~ {
      csv_path <-
        here::here(
          "Outputs/Data/VegVault/Flat_files",
          "Column_names",
          paste0(.x, "_columns.csv")
        )

      data_empty_tibble <-
        dplyr::tbl(con, .x) %>%
        head(0) %>%
        dplyr::collect()

      # Get the column names and types
      col_info <-
        tibble::tibble(
          column_name = colnames(data_empty_tibble),
          data_type = purrr::map_chr(data_empty_tibble, ~ class(.x))
        ) %>%
        as.data.frame()

      if (
        isTRUE(rewrite) && isFALSE(file.exists(csv_path))
      ) {
        readr::write_csv(
          x = col_info,
          file = csv_path
        )
      }

      return(col_info)
    }
  ) %>%
  purrr::imap(
    .f = ~ .x %>%
      dplyr::rename(
        `Column name` = column_name,
        `Data type` = data_type
      ) %>%
      tibble::add_column(Description = NA_character_) %>%
      knitr::kable(
        caption = paste0("Table X: Column names and types for table ", .y),
        align = "l"
      )
  ) %>%
  arsenal::write2word(
    file = here::here(
      "Outputs/Data/VegVault/Flat_files",
      "Column_names",
      "VegVault_column_names.docx"
    )
  )

DBI::dbDisconnect(con)
