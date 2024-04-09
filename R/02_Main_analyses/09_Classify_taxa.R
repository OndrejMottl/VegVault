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

vec_problematictaxa_names <-
  c(
    "Atriplex hortensis",
    "Hydrocotyle bonariensis"
  )

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

# load all classified data
taxa_already_present_raw <-
  here::here(
    "Data/Processed/Classified_taxa/"
  ) %>%
  list.files(
    pattern = ".rds",
    full.names = TRUE
  )

if (
  length(taxa_already_present_raw) > 0
) {
  taxa_already_classified <-
    taxa_already_present_raw %>%
    purrr::map(
      .progress = TRUE,
      .f = ~ readr::read_rds(.x)
    ) %>%
    dplyr::bind_rows() %>%
    dplyr::distinct(sel_name, .keep_all = TRUE)

  taxa_already_classified_vec <-
    taxa_already_classified %>%
    dplyr::filter(
      is.na(id) == FALSE
    ) %>%
    purrr::chuck("sel_name")

  taxa_to_classify <-
    taxa_db %>%
    dplyr::filter(
      !taxon_name %in% taxa_already_classified_vec
    )
} else {
  taxa_to_classify <- taxa_db
}

taxa_db_chuncked <-
  taxa_to_classify %>%
  # There are ceratin taxa that are unable to be classified.
  # These are removed from the list and classified separately
  dplyr::filter(
    !taxon_name %in% vec_problematictaxa_names
  ) %>%
  dplyr::mutate(
    chunk_id = (dplyr::row_number() - 1) %/% chunk_size
  ) %>%
  dplyr::group_by(chunk_id) %>%
  tidyr::nest(data_nested = -chunk_id) %>%
  dplyr::ungroup()


#----------------------------------------------------------#
# 3. Classify taxa using {taxospace} -----
#----------------------------------------------------------#

# classify all taxa
purrr::walk(
  .progress = TRUE,
  .x = taxa_db_chuncked$data_nested,
  .f = ~ {
    sel_class <-
      taxospace::get_classification(
        taxa_vec = .x$taxon_name,
        sel_db_name = "gnr",
        sel_db_class = "gbif",
        use_cache = TRUE,
        verbose = FALSE
      )

    sel_class %>%
      split(., .$sel_name) %>%
      purrr::iwalk(
        .f = ~ RUtilpol::save_latest_file(
          file_name = janitor::make_clean_names(.y),
          object_to_save = .x,
          dir = here::here("Data/Processed/Classified_taxa/"),
          prefered_format = "rds",
          verbose = FALSE
        )
      )
  }
)

#----------------------------------------------------------#
# 4. Classify taxa using {taxospace} without `cache` -----
#----------------------------------------------------------#

# load all classified data
taxa_already_classified <-
  here::here(
    "Data/Processed/Classified_taxa/"
  ) %>%
  list.files(
    pattern = ".rds",
    full.names = TRUE
  ) %>%
  purrr::map(
    .progress = TRUE,
    .f = ~ readr::read_rds(.x)
  ) %>%
  dplyr::bind_rows() %>%
  dplyr::distinct(sel_name, .keep_all = TRUE)


taxa_already_classified_vec <-
  taxa_already_classified %>%
  # only consider taxa that have been classified successfully
  dplyr::filter(
    is.na(id) == FALSE
  ) %>%
  purrr::chuck("sel_name")

taxa_to_classify <-
  taxa_db %>%
  dplyr::filter(
    !taxon_name %in% taxa_already_classified_vec
  )

taxa_db_chuncked <-
  taxa_to_classify %>%
  dplyr::mutate(
    chunk_id = (dplyr::row_number() - 1) %/% (chunk_size / 5) # decrease the size
  ) %>%
  dplyr::group_by(chunk_id) %>%
  tidyr::nest(data_nested = -chunk_id) %>%
  dplyr::ungroup()

# classify all taxa
purrr::walk(
  .progress = TRUE,
  .x = taxa_db_chuncked$data_nested,
  .f = ~ {
    sel_class <-
      taxospace::get_classification(
        taxa_vec = .x$taxon_name,
        sel_db_name = "gnr",
        sel_db_class = "gbif",
        # do not use cache, this will take time
        #   but solve some issues with weird names
        use_cache = FALSE,
        verbose = FALSE
      )

    sel_class %>%
      split(., .$sel_name) %>%
      purrr::iwalk(
        .f = ~ RUtilpol::save_latest_file(
          file_name = janitor::make_clean_names(.y),
          object_to_save = .x,
          dir = here::here("Data/Processed/Classified_taxa/"),
          prefered_format = "rds",
          verbose = FALSE
        )
      )
  }
)


#----------------------------------------------------------#
# 5. Classify taxa using up to family -----
#----------------------------------------------------------#

# load all classified data
taxa_all_classified <-
  here::here(
    "Data/Processed/Classified_taxa/"
  ) %>%
  list.files(
    pattern = ".rds",
    full.names = TRUE
  ) %>%
  purrr::map(
    .progress = TRUE,
    .f = ~ readr::read_rds(.x)
  ) %>%
  dplyr::bind_rows() %>%
  dplyr::distinct(sel_name, .keep_all = TRUE) %>%
  # only consider taxa that have been classified successfully
  dplyr::filter(
    is.na(id) == FALSE
  ) %>%
  dplyr::inner_join(
    taxa_db,
    by = dplyr::join_by("sel_name" == "taxon_name")
  )

data_classified_up_to_family <-
  taxa_all_classified %>%
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


#----------------------------------------------------------#
# 4. add new taxa to DB -----
#----------------------------------------------------------#

data_classified_up_to_family %>%
  tidyr::pivot_longer(
    cols = c("species", "genus", "family"),
    names_to = "rank",
    values_to = "taxon_name"
  ) %>%
  dplyr::distinct(taxon_name) %>%
  tidyr::drop_na() %>%
  dplyr::mutate(
    taxon_reference = "added manually by Ondrej Mottl",
  ) %>%
  add_taxa(con = con)


#----------------------------------------------------------#
# 5. add classification to DB -----
#----------------------------------------------------------#

# update the taxa list
taxa_db <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::collect()

data_classified_up_to_family %>%
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

#----------------------------------------------------------#
# 6. Solve unclassified -----
#---------------------------------------------------------#

# update the taxa list
taxa_db <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::collect()

taxa_to_classify <-
  dplyr::left_join(
    dplyr::tbl(con, "Taxa"),
    dplyr::tbl(con, "TaxonClassification"),
    by = "taxon_id"
  ) %>%
  dplyr::filter(
    is.na(taxon_species) &
      is.na(taxon_genus) &
      is.na(taxon_family)
  ) %>%
  dplyr::distinct(taxon_name) %>%
  dplyr::collect()

# chunk the data
taxa_db_chuncked <-
  taxa_to_classify %>%
  dplyr::mutate(
    chunk_id = (dplyr::row_number() - 1) %/% chunk_size
  ) %>%
  dplyr::group_by(chunk_id) %>%
  tidyr::nest(data_nested = -chunk_id) %>%
  dplyr::ungroup()

# classify all taxa
taxa_classified <-
  purrr::map(
    .progress = TRUE,
    .x = taxa_db_chuncked$data_nested,
    .f = purrr::possibly(
      ~ taxospace::get_classification(
        taxa_vec = .x$taxon_name,
        sel_db_name = "gnr",
        sel_db_class = "gbif",
        use_cache = FALSE,
        verbose = FALSE
      )
    )
  ) %>%
  dplyr::bind_rows()

# filter out NULL results
taxa_all_classified <-
  taxa_classified %>%
  dplyr::filter(
    !is.na(id)
  ) %>%
  dplyr::inner_join(
    taxa_db,
    by = dplyr::join_by("sel_name" == "taxon_name")
  )

# classify up to family
data_classified_up_to_family <-
  taxa_all_classified %>%
  dplyr::select(sel_name, classification) %>%
  dplyr::distinct(sel_name, .keep_all = TRUE) %>%
  tidyr::unnest(cols = classification) %>%
  dplyr::select(-id) %>%
  dplyr::filter(
    rank == "species" |
      rank == "genus" |
      rank == "family"
  ) %>%
  dplyr::distinct() %>%
  tidyr::pivot_wider(
    names_from = rank,
    values_from = name,
    values_fill = NA_character_
  )

# add new taxa to DB
data_classified_up_to_family %>%
  tidyr::pivot_longer(
    cols = c("species", "genus", "family"),
    names_to = "rank",
    values_to = "taxon_name"
  ) %>%
  dplyr::distinct(taxon_name) %>%
  tidyr::drop_na() %>%
  dplyr::mutate(
    taxon_reference = "added manually by Ondrej Mottl",
  ) %>%
  add_taxa(con = con)

# update the taxa list
taxa_db <-
  dplyr::tbl(con, "Taxa") %>%
  dplyr::collect()

# add classification to DB
data_classified_up_to_family %>%
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

#----------------------------------------------------------#
# 7. Disconect DB -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
