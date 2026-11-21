library(DBI)
library(RSQLite)
library(dplyr)
library(tidyr)
library(purrr)
library(readr)
library(tibble)
library(here)

source(here::here("R", "Functions", "validate_unique_rows.R"))
source(here::here("R", "Functions", "save_table_rows.R"))
source(here::here("R", "Functions", "Traits", "save_trait_rules.R"))
source(here::here("R", "Functions", "Traits", "validate_trait_import.R"))
source(here::here("R", "Functions", "Traits", "save_trait_value.R"))

path_database <- tempfile(fileext = ".sqlite")
con <- DBI::dbConnect(RSQLite::SQLite(), path_database)
on.exit({
  DBI::dbDisconnect(con)
  unlink(path_database)
})
DBI::dbExecute(con, "PRAGMA foreign_keys = ON")

sql <- paste(readLines(here::here("Data", "SQL", "make_tables.sql")), collapse = "\n")
statements <- strsplit(sql, ";", fixed = TRUE)[[1]]
invisible(
  lapply(
    statements[nzchar(trimws(statements))],
    DBI::dbExecute,
    conn = con
  )
)

rules <- save_trait_rules(con)
stopifnot(nrow(rules$conversions) > 0L, nrow(rules$derivations) == 1L)

DBI::dbExecute(con, "INSERT INTO TraitsDomain VALUES (1, 'Leaf Area', 'mm2', NULL)")
DBI::dbExecute(con, "INSERT INTO Traits VALUES (1, 1, 'leaf area')")
DBI::dbExecute(con, "INSERT INTO Datasets (dataset_id, dataset_name) VALUES (1, 'd1')")
DBI::dbExecute(con, "INSERT INTO Samples (sample_id, sample_name) VALUES (1, 's1')")
DBI::dbExecute(con, "INSERT INTO Taxa (taxon_id, taxon_name) VALUES (1, 'taxon')")

data_source <-
  tibble::tibble(
    source_provider = "TRY",
    source_dataset_key = "fixture",
    source_record_id = "record-1",
    source_trait_id = "3114",
    original_value_string = "1",
    original_unit = "mm2",
    normalized_original_unit = "mm2",
    conversion_status = "identity",
    conversion_rule_key = "try_leaf_area_3114_mm2",
    derivation_rule_key = NA_character_,
    trait_unit = "mm2",
    dataset_name = "d1",
    sample_name = "s1",
    trait_name = "leaf area",
    taxon_name = "taxon",
    trait_value = 1
  )

audit <-
  save_trait_value(
    data_source = data_source,
    dataset_id = tibble::tibble(dataset_id = 1L, dataset_name = "d1"),
    samples_id = tibble::tibble(sample_id = 1L, sample_name = "s1"),
    traits_id = tibble::tibble(trait_id = 1L, trait_name = "leaf area"),
    taxa_id = tibble::tibble(taxon_id = 1L, taxon_name = "taxon"),
    con = con
  )

stopifnot(
  nrow(audit) == 1L,
  DBI::dbGetQuery(con, "SELECT COUNT(*) AS n FROM TraitsValue")$n == 1L,
  nrow(DBI::dbGetQuery(con, "PRAGMA foreign_key_check")) == 0L
)

duplicate_error <-
  tryCatch(
    {
      save_trait_value(
        data_source = data_source,
        dataset_id = tibble::tibble(dataset_id = 1L, dataset_name = "d1"),
        samples_id = tibble::tibble(sample_id = 1L, sample_name = "s1"),
        traits_id = tibble::tibble(trait_id = 1L, trait_name = "leaf area"),
        taxa_id = tibble::tibble(taxon_id = 1L, taxon_name = "taxon"),
        con = con
      )
      FALSE
    },
    error = function(error) TRUE
  )
stopifnot(duplicate_error)

message("VegVault v2 trait integration test passed")
