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


#----------------------------------------------------------#
# 2. Get all taxa from DB -----
#----------------------------------------------------------#

taxa_db <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::collect()


taxa_db_chuncked <-
  dplyr::mutate(
    taxa_db,
    chunk_id = (dplyr::row_number() - 1) %/% chunk_size
  ) %>%
  dplyr::group_by(chunk_id) %>%
  tidyr::nest(data_nested = -chunk_id) %>%
  dplyr::ungroup()


#----------------------------------------------------------#
# 3. Classify taxa using {taxospace} -----
#----------------------------------------------------------#

taxa_db_classified <-
  taxa_db_chuncked %>%
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

data_classified_up_to_family <-
  taxa_db_classified %>%
  dplyr::mutate(
    data_merged = purrr::map(
      .progress = TRUE,
      .x = data_classified,
      .f = ~ .x %>%
        dplyr::select(sel_name, classification) %>%
        dplyr::distinct(sel_name, .keep_all = TRUE) %>%
        tidyr::unnest(cols = classification) %>%
        dplyr::select(-id) %>%
        dplyr::filter(
          rank == "species" |
            rank == "genus" |
            rank == "family"
        ) %>%
        tidyr::pivot_wider(
          names_from = rank,
          values_from = name,
          values_fill = NA_character_
        )
    )
  )

#----------------------------------------------------------#
# 4. add new taxa to DB -----
#----------------------------------------------------------#

purrr::walk(
  .progress = TRUE,
  .x = data_classified_up_to_family$data_merged,
  .f = ~ .x %>%
    tidyr::pivot_longer(
      cols = c("species", "genus", "family"),
      names_to = "rank",
      values_to = "taxon_name"
    ) %>%
    dplyr::distinct(taxon_name) %>%
    tidyr::drop_na() %>%
    add_taxa(con = con)
)


#----------------------------------------------------------#
# 5. add classification to DB -----
#----------------------------------------------------------#

# update the taxa list
taxa_db <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::collect()


purrr::walk(
  .progress = TRUE,
  .x = data_classified_up_to_family$data_merged,
  .f = ~ .x %>%
    tidyr::pivot_longer(
      cols = c("species", "genus", "family"),
      names_to = "rank",
      values_to = "taxon_name"
    ) %>%
    dplyr::left_join(
      taxa_db,
      by = dplyr::join_by("taxon_name")
    ) %>%
    dplyr::select(-taxon_name) %>%
    tidyr::pivot_wider(
      names_from = rank,
      values_from = taxon_id,
      values_fill = NA_integer_,
      names_prefix = "taxon_"
    ) %>%
    dplyr::left_join(
      taxa_db,
      by = dplyr::join_by("sel_name" == "taxon_name")
    ) %>%
    dplyr::select(-sel_name) %>%
    dplyr::relocate(taxon_id) %>%
    add_taxa_classification(con = con)
)

#----------------------------------------------------------#
# 6. Disconect DB -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
