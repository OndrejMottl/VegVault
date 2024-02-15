#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#                Classify all taxa is DB
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

if (
  isFALSE(require("taxospace"))
) {
  remotes::install_github("OndrejMottl/taxospace")
  library(taxospace)
}

chunk_size <- 500

#----------------------------------------------------------#
# 1. Connect to db -----
#----------------------------------------------------------#

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  )

DBI::dbListTables(con)


# Get all taxa from DB -----

taxa_db <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::collect()


taxa_db_chuncked <-
  dplyr::mutate(
    taxa_db,
    chunk_id = (dplyr::row_number() - 1) %/% chunk_size
  ) %>%
  dplyr::group_by(chunk_id) %>%
  tidyr::nest(data_nested = -chunk_id)


# Classify taxa using {taxospace} -----

taxa_db_classified <-
  taxa_db_chuncked[1, ] %>%
  dplyr::mutate(
    data_classified = purrr::map(
      .progress = TRUE,
      .x = data_nested,
      .f = ~ taxospace::get_classification(
        taxa_vec = .x$taxon_name,
        sel_db_name = "gnr",
        sel_db_class = "gbif",
        use_cache = TRUE,
        verbose = FALSE
      )
    )
  )


# add new taxa to DB -----

dplyr::tbl(con, "TaxonClassification") %>%
  dplyr::collect()


# add classification to DB -----
