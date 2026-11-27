#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Extract a regional subset of the v1.0.0 database
#           - into a new, disposable SQLite file
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Copy every v1.0.0 row that belongs to the bounding box in
#   `research_settings.yml` into a new SQLite file with the exact v1.0.0
#   schema and the original ids. The subset holds the non-gridpoint
#   datasets inside the box, the gridpoint cells inside the box plus a
#   50 km margin, every gridpoint referenced by a link of a box sample, and
#   all rows that hang on these datasets, samples and taxa. Small lookup
#   tables are copied whole. It is the reference for the build prototypes
#   and the v1 link comparison.
# v1.0.0 is read through primary-key and index lookups only, on a
#   read-only connection; its size, modification time, and header are
#   compared before and after. The subset is written to `<name>.partial`
#   and renamed only when complete. An existing subset file is never
#   overwritten unless `flag_overwrite` is set to TRUE.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (resolves `path_to_vegvault` from the secrets file)
source(
  here::here("R/00_Config_file.R")
)

flag_overwrite <- FALSE

list_settings_subset <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  ) |>
  purrr::chuck("subset")

path_subset_dir <-
  here::here("Data", "Temp", "Database_research", "Subset")

path_subset <-
  base::file.path(
    path_subset_dir,
    stringr::str_c(
      "v1_subset_",
      purrr::chuck(list_settings_subset, "box_name"),
      ".sqlite"
    )
  )

path_subset_partial <-
  stringr::str_c(path_subset, ".partial")

path_output <-
  here::here("Data", "Temp", "Database_research", "V1_subset_extraction")

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

# Lookup tables below 10,000 rows (rowid bounds in v1.0.0) are copied whole
vec_tables_copied_whole <-
  c(
    "version_control",
    "Authors",
    "DatasetTypeID",
    "DatasetSourceTypeID",
    "DatasetSourceTypeReference",
    "DatasetSourcesID",
    "DatasetSourcesReference",
    "SamplingMethodID",
    "SamplingMethodReference",
    "SampleSizeID",
    "AbioticVariable",
    "AbioticVariableReference",
    "Traits",
    "TraitsDomain",
    "TraitsReference",
    "References"
  )

time_run_start <-
  base::Sys.time()

assertthat::assert_that(
  base::file.exists(path_to_vegvault),
  msg = "The database file named in the secrets file does not exist."
)

if (
  base::file.exists(path_subset) && base::isFALSE(flag_overwrite)
) {
  cli::cli_abort(
    c(
      "The subset file already exists: {.path {path_subset}}.",
      "i" = "Set `flag_overwrite` to TRUE to rebuild it."
    )
  )
}

base::dir.create(
  path = path_subset_dir,
  recursive = TRUE,
  showWarnings = FALSE
)

base::dir.create(
  path = path_output,
  recursive = TRUE,
  showWarnings = FALSE
)

# A leftover partial file is from an interrupted run of this script
base::unlink(path_subset_partial)


#----------------------------------------------------------#
# 1. Record the v1.0.0 file state before connecting -----
#----------------------------------------------------------#

vec_header_raw_before <-
  base::readBin(
    con = path_to_vegvault,
    what = "raw",
    n = 100L
  )

size_bytes_before <-
  base::file.size(path_to_vegvault)

mtime_before <-
  base::file.mtime(path_to_vegvault)

# A WAL-mode reader may create a `-shm` file next to the database, so the
#   file is only opened when it uses a rollback journal
if (
  base::as.integer(vec_header_raw_before[19L]) != 1L ||
    base::as.integer(vec_header_raw_before[20L]) != 1L ||
    base::any(
      base::file.exists(
        stringr::str_c(path_to_vegvault, vec_sibling_suffix)
      )
    )
) {
  cli::cli_abort(
    c(
      "The database is in WAL mode or has a journal file next to it.",
      "i" = "It was not opened, to avoid creating files next to it."
    )
  )
}


#----------------------------------------------------------#
# 2. Copy the subset -----
#----------------------------------------------------------#

con_v1 <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_to_vegvault,
    flags = RSQLite::SQLITE_RO
  )

con_subset <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_subset_partial
  )

tryCatch(
  expr = {
    #--------------------------------------------------#
    ## 2.1. Create the v1.0.0 tables -----
    #--------------------------------------------------#

    # The disposable file needs no crash safety while it is written
    DBI::dbExecute(conn = con_subset, statement = "PRAGMA journal_mode = OFF")

    DBI::dbExecute(conn = con_subset, statement = "PRAGMA synchronous = OFF")

    data_schema_v1 <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT type, name, sql FROM sqlite_master ",
          "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'"
        )
      ) |>
      tibble::as_tibble()

    purrr::walk(
      .x = data_schema_v1 |>
        dplyr::filter(type == "table") |>
        dplyr::pull(sql),
      .f = ~ DBI::dbExecute(conn = con_subset, statement = .x)
    )

    #--------------------------------------------------#
    ## 2.2. Datasets in the box and gridpoint cells -----
    #--------------------------------------------------#

    time_step_start <-
      base::Sys.time()

    sql_datasets_in_box <-
      stringr::str_c(
        "SELECT * FROM Datasets ",
        "INDEXED BY idx_datasets_coord_long_lat ",
        "WHERE coord_long BETWEEN ? AND ? AND coord_lat BETWEEN ? AND ?"
      )

    data_datasets_box <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = sql_datasets_in_box,
        params = list(
          purrr::chuck(list_settings_subset, "lon_min"),
          purrr::chuck(list_settings_subset, "lon_max"),
          purrr::chuck(list_settings_subset, "lat_min"),
          purrr::chuck(list_settings_subset, "lat_max")
        )
      ) |>
      tibble::as_tibble() |>
      dplyr::filter(dataset_type_id != 4L)

    data_datasets_grid_margin <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = sql_datasets_in_box,
        params = list(
          purrr::chuck(list_settings_subset, "lon_min") -
            purrr::chuck(list_settings_subset, "margin_lon"),
          purrr::chuck(list_settings_subset, "lon_max") +
            purrr::chuck(list_settings_subset, "margin_lon"),
          purrr::chuck(list_settings_subset, "lat_min") -
            purrr::chuck(list_settings_subset, "margin_lat"),
          purrr::chuck(list_settings_subset, "lat_max") +
            purrr::chuck(list_settings_subset, "margin_lat")
        )
      ) |>
      tibble::as_tibble() |>
      dplyr::filter(dataset_type_id == 4L)

    data_dataset_sample_box <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM DatasetSample WHERE dataset_id = ?",
        params = list(
          c(
            data_datasets_box |>
              dplyr::pull(dataset_id),
            data_datasets_grid_margin |>
              dplyr::pull(dataset_id)
          )
        )
      ) |>
      tibble::as_tibble()

    vec_sample_id_not_gridpoint <-
      data_dataset_sample_box |>
      dplyr::semi_join(
        data_datasets_box,
        by = dplyr::join_by(dataset_id)
      ) |>
      dplyr::distinct(sample_id) |>
      dplyr::pull(sample_id)

    seconds_datasets <-
      base::difftime(base::Sys.time(), time_step_start, units = "secs") |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.3. Links of the box samples, in chunks -----
    #--------------------------------------------------#

    time_step_start_links <-
      base::Sys.time()

    list_sample_id_chunks <-
      base::split(
        x = vec_sample_id_not_gridpoint,
        f = base::ceiling(
          base::seq_along(vec_sample_id_not_gridpoint) /
            purrr::chuck(list_settings_subset, "link_chunk_size")
        )
      )

    DBI::dbWithTransaction(
      conn = con_subset,
      code = purrr::walk(
        .x = list_sample_id_chunks,
        .f = ~ DBI::dbAppendTable(
          conn = con_subset,
          name = "AbioticDataReference",
          value = DBI::dbGetQuery(
            conn = con_v1,
            statement = stringr::str_c(
              "SELECT * FROM AbioticDataReference WHERE sample_id = ?"
            ),
            params = list(.x)
          )
        )
      )
    )

    # Gridpoints referenced by the links, read back from the new subset
    vec_sample_ref_id <-
      DBI::dbGetQuery(
        conn = con_subset,
        statement = stringr::str_c(
          "SELECT DISTINCT sample_ref_id FROM AbioticDataReference"
        )
      ) |>
      dplyr::pull(sample_ref_id)

    seconds_links <-
      base::difftime(
        base::Sys.time(),
        time_step_start_links,
        units = "secs"
      ) |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.4. Referenced gridpoints outside the margin -----
    #--------------------------------------------------#

    time_step_start_rows <-
      base::Sys.time()

    vec_sample_ref_id_outside <-
      base::setdiff(
        vec_sample_ref_id,
        data_dataset_sample_box |>
          dplyr::pull(sample_id)
      )

    data_dataset_sample_outside <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM DatasetSample WHERE sample_id = ?",
        params = list(vec_sample_ref_id_outside)
      ) |>
      tibble::as_tibble()

    data_datasets_outside <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM Datasets WHERE dataset_id = ?",
        params = list(
          data_dataset_sample_outside |>
            dplyr::distinct(dataset_id) |>
            dplyr::pull(dataset_id)
        )
      ) |>
      tibble::as_tibble()

    data_datasets_subset <-
      dplyr::bind_rows(
        data_datasets_box,
        data_datasets_grid_margin,
        data_datasets_outside
      ) |>
      dplyr::distinct()

    data_dataset_sample_subset <-
      dplyr::bind_rows(
        data_dataset_sample_box,
        data_dataset_sample_outside
      ) |>
      dplyr::distinct()

    vec_dataset_id_subset <-
      data_datasets_subset |>
      dplyr::pull(dataset_id)

    vec_sample_id_subset <-
      data_dataset_sample_subset |>
      dplyr::distinct(sample_id) |>
      dplyr::pull(sample_id)

    vec_sample_id_gridpoint <-
      base::setdiff(vec_sample_id_subset, vec_sample_id_not_gridpoint)

    #--------------------------------------------------#
    ## 2.5. Rows of the subset samples and datasets -----
    #--------------------------------------------------#

    data_samples_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM Samples WHERE sample_id = ?",
        params = list(vec_sample_id_subset)
      ) |>
      tibble::as_tibble()

    data_abiotic_data_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM AbioticData WHERE sample_id = ?",
        params = list(vec_sample_id_gridpoint)
      ) |>
      tibble::as_tibble()

    data_sample_taxa_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM SampleTaxa WHERE sample_id = ?",
        params = list(vec_sample_id_not_gridpoint)
      ) |>
      tibble::as_tibble()

    data_sample_uncertainty_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM SampleUncertainty WHERE sample_id = ?",
        params = list(vec_sample_id_not_gridpoint)
      ) |>
      tibble::as_tibble()

    data_sample_reference_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM SampleReference WHERE sample_id = ?",
        params = list(vec_sample_id_subset)
      ) |>
      tibble::as_tibble()

    data_dataset_references_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM DatasetReferences WHERE dataset_id = ?",
        params = list(vec_dataset_id_subset)
      ) |>
      tibble::as_tibble()

    data_traits_value_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM TraitsValue WHERE dataset_id = ?",
        params = list(vec_dataset_id_subset)
      ) |>
      tibble::as_tibble()

    #--------------------------------------------------#
    ## 2.6. Taxa and their classification -----
    #--------------------------------------------------#

    vec_taxon_id_used <-
      c(
        data_sample_taxa_subset |>
          dplyr::pull(taxon_id),
        data_traits_value_subset |>
          dplyr::pull(taxon_id)
      ) |>
      base::unique()

    data_taxon_classification_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT * FROM TaxonClassification WHERE taxon_id = ?"
        ),
        params = list(vec_taxon_id_used)
      ) |>
      tibble::as_tibble()

    vec_taxon_id_subset <-
      c(
        vec_taxon_id_used,
        data_taxon_classification_subset |>
          dplyr::pull(taxon_species),
        data_taxon_classification_subset |>
          dplyr::pull(taxon_genus),
        data_taxon_classification_subset |>
          dplyr::pull(taxon_family)
      ) |>
      base::unique() |>
      purrr::discard(.p = base::is.na)

    data_taxa_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM Taxa WHERE taxon_id = ?",
        params = list(vec_taxon_id_subset)
      ) |>
      tibble::as_tibble()

    data_taxon_reference_subset <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT * FROM TaxonReference WHERE taxon_id = ?",
        params = list(vec_taxon_id_subset)
      ) |>
      tibble::as_tibble()

    #--------------------------------------------------#
    ## 2.7. Small lookup tables, copied whole -----
    #--------------------------------------------------#

    list_tables_whole <-
      vec_tables_copied_whole |>
      rlang::set_names() |>
      purrr::map(
        .f = ~ DBI::dbReadTable(conn = con_v1, name = .x) |>
          tibble::as_tibble()
      )

    seconds_rows <-
      base::difftime(
        base::Sys.time(),
        time_step_start_rows,
        units = "secs"
      ) |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.8. Write all tables except the links -----
    #--------------------------------------------------#

    time_step_start_write <-
      base::Sys.time()

    list_tables_subset <-
      c(
        list_tables_whole,
        list(
          Datasets = data_datasets_subset,
          DatasetSample = data_dataset_sample_subset,
          Samples = data_samples_subset,
          AbioticData = data_abiotic_data_subset,
          SampleTaxa = data_sample_taxa_subset,
          SampleUncertainty = data_sample_uncertainty_subset,
          SampleReference = data_sample_reference_subset,
          DatasetReferences = data_dataset_references_subset,
          TraitsValue = data_traits_value_subset,
          TaxonClassification = data_taxon_classification_subset,
          Taxa = data_taxa_subset,
          TaxonReference = data_taxon_reference_subset
        )
      )

    DBI::dbWithTransaction(
      conn = con_subset,
      code = purrr::iwalk(
        .x = list_tables_subset,
        .f = ~ DBI::dbAppendTable(
          conn = con_subset,
          name = .y,
          value = .x
        )
      )
    )

    seconds_write <-
      base::difftime(
        base::Sys.time(),
        time_step_start_write,
        units = "secs"
      ) |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.9. Indexes and statistics, as in v1.0.0 -----
    #--------------------------------------------------#

    time_step_start_index <-
      base::Sys.time()

    purrr::walk(
      .x = data_schema_v1 |>
        dplyr::filter(type == "index") |>
        dplyr::pull(sql),
      .f = ~ DBI::dbExecute(conn = con_subset, statement = .x)
    )

    DBI::dbExecute(conn = con_subset, statement = "ANALYZE")

    seconds_index <-
      base::difftime(
        base::Sys.time(),
        time_step_start_index,
        units = "secs"
      ) |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.10. Check the subset -----
    #--------------------------------------------------#

    data_subset_row_counts <-
      DBI::dbListTables(conn = con_subset) |>
      purrr::discard(.p = ~ stringr::str_detect(.x, "^sqlite_")) |>
      purrr::map(
        .f = ~ tibble::tibble(
          table_name = .x,
          n_rows = DBI::dbGetQuery(
            conn = con_subset,
            statement = stringr::str_c(
              "SELECT count(*) AS n FROM \"", .x, "\""
            )
          ) |>
            dplyr::pull(n)
        )
      ) |>
      dplyr::bind_rows()

    data_foreign_key_violations <-
      DBI::dbGetQuery(
        conn = con_subset,
        statement = "PRAGMA foreign_key_check"
      ) |>
      tibble::as_tibble()

    # The PRAGMA returns no columns at all when there is no violation
    data_subset_foreign_key_check <-
      if (
        base::nrow(data_foreign_key_violations) == 0L
      ) {
        tibble::tibble(
          table = base::character(),
          parent = base::character(),
          n_violations = base::integer()
        )
      } else {
        data_foreign_key_violations |>
          dplyr::count(table, parent, name = "n_violations")
      }

    value_subset_quick_check <-
      DBI::dbGetQuery(
        conn = con_subset,
        statement = "PRAGMA quick_check"
      ) |>
      dplyr::pull(var = 1) |>
      stringr::str_c(collapse = "; ")
  },
  finally = {
    DBI::dbDisconnect(con_v1)
    DBI::dbDisconnect(con_subset)
  }
)


#----------------------------------------------------------#
# 3. Check that v1.0.0 was not changed -----
#----------------------------------------------------------#

vec_header_raw_after <-
  base::readBin(
    con = path_to_vegvault,
    what = "raw",
    n = 100L
  )

flag_file_unchanged <-
  base::isTRUE(
    base::file.size(path_to_vegvault) == size_bytes_before &&
      base::file.mtime(path_to_vegvault) == mtime_before &&
      base::identical(vec_header_raw_before, vec_header_raw_after) &&
      !base::any(
        base::file.exists(
          stringr::str_c(path_to_vegvault, vec_sibling_suffix)
        )
      )
  )

if (
  base::isFALSE(flag_file_unchanged)
) {
  cli::cli_abort(
    "The v1.0.0 database file differs after the read-only session."
  )
}


#----------------------------------------------------------#
# 4. Save the subset and the extraction record -----
#----------------------------------------------------------#

base::file.rename(
  from = path_subset_partial,
  to = path_subset
)

data_run_info <-
  tibble::tibble(
    script = "04_extract_v1_subset.R",
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    box_name = purrr::chuck(list_settings_subset, "box_name"),
    lon_min = purrr::chuck(list_settings_subset, "lon_min"),
    lon_max = purrr::chuck(list_settings_subset, "lon_max"),
    lat_min = purrr::chuck(list_settings_subset, "lat_min"),
    lat_max = purrr::chuck(list_settings_subset, "lat_max"),
    margin_lon = purrr::chuck(list_settings_subset, "margin_lon"),
    margin_lat = purrr::chuck(list_settings_subset, "margin_lat"),
    subset_size_bytes = base::file.size(path_subset),
    subset_quick_check = value_subset_quick_check,
    v1_connection_flags = "SQLITE_RO",
    v1_file_unchanged = flag_file_unchanged
  )

data_step_seconds <-
  tibble::tibble(
    step = c("datasets", "links", "other_rows", "write", "indexes"),
    seconds = c(
      seconds_datasets,
      seconds_links,
      seconds_rows,
      seconds_write,
      seconds_index
    )
  )

list_outputs <-
  list(
    run_info = data_run_info,
    step_seconds = data_step_seconds,
    subset_row_counts = data_subset_row_counts,
    subset_foreign_key_check = data_subset_foreign_key_check
  )

purrr::iwalk(
  .x = list_outputs,
  .f = ~ readr::write_csv(
    x = .x,
    file = base::file.path(path_output, stringr::str_c(.y, ".csv"))
  )
)

cli::cli_inform(
  c(
    "v" = "Subset written; v1.0.0 is unchanged.",
    "i" = "Subset: {.path {path_subset}}."
  )
)
