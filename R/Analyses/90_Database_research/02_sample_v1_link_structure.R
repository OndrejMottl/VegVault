#----------------------------------------------------------#
#
#
#                       VegVault
#
#          Sample the v1.0.0 sample and link structure
#             - primary-key and index lookups only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Estimate the composition of `Samples` by dataset type and source, and the
#   structure of the gridpoint links (links, cells and ages per sample,
#   stored types of the distance columns), from random samples of rowids.
#   Every query is a primary-key lookup or an index range on one key value,
#   so no table is scanned. The file is opened read-only, and its size,
#   modification time, and header are compared before and after. The
#   results are sample-based estimates, not exact counts.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (resolves `path_to_vegvault` from the secrets file)
source(
  here::here("R/00_Config_file.R")
)

path_output <-
  here::here("Data", "Temp", "Database_research", "V1_link_sample")

base::dir.create(
  path = path_output,
  recursive = TRUE,
  showWarnings = FALSE
)

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

# Sizes of the random draws
n_samples_uniform <- 300000L
n_samples_per_stratum <- 1000L
n_gridpoint_cells_spacing <- 200L
n_samples_max_for_age_count <- 20000L

# Seed of the project configuration, set again so this script is
#   reproducible on its own
base::set.seed(1234)

time_run_start <-
  base::Sys.time()

assertthat::assert_that(
  base::file.exists(path_to_vegvault),
  msg = "The database file named in the secrets file does not exist."
)


#----------------------------------------------------------#
# 1. Record the file state before connecting -----
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

vec_sibling_exists_before <-
  base::file.exists(
    stringr::str_c(path_to_vegvault, vec_sibling_suffix)
  )

# A WAL-mode reader may create a `-shm` file next to the database, so the
#   file is only opened when it uses a rollback journal
if (
  base::as.integer(vec_header_raw_before[19L]) != 1L ||
    base::as.integer(vec_header_raw_before[20L]) != 1L ||
    base::any(vec_sibling_exists_before)
) {
  cli::cli_abort(
    c(
      "The database is in WAL mode or has a journal file next to it.",
      "i" = "It was not opened, to avoid creating files next to it."
    )
  )
}


#----------------------------------------------------------#
# 2. Query through a read-only connection -----
#----------------------------------------------------------#

con_v1 <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_to_vegvault,
    flags = RSQLite::SQLITE_RO,
    bigint = "numeric"
  )

tryCatch(
  expr = {
    #--------------------------------------------------#
    ## 2.1. Classify a uniform random draw of samples -----
    #--------------------------------------------------#

    time_step_start <-
      base::Sys.time()

    n_samples_total <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = "SELECT max(rowid) AS value FROM Samples"
      ) |>
      dplyr::pull(value)

    vec_sample_id_uniform <-
      base::sample.int(
        n = n_samples_total,
        size = n_samples_uniform,
        replace = FALSE
      ) |>
      base::sort()

    data_samples_uniform <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT sample_id, age, sample_size_id ",
          "FROM Samples WHERE sample_id = ?"
        ),
        params = list(vec_sample_id_uniform)
      ) |>
      tibble::as_tibble()

    data_dataset_sample_uniform <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT sample_id, dataset_id ",
          "FROM DatasetSample WHERE sample_id = ?"
        ),
        params = list(vec_sample_id_uniform)
      ) |>
      tibble::as_tibble()

    vec_dataset_id_uniform <-
      data_dataset_sample_uniform |>
      dplyr::distinct(dataset_id) |>
      dplyr::pull(dataset_id)

    data_datasets_uniform <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT dataset_id, dataset_type_id, data_source_type_id, ",
          "coord_long, coord_lat FROM Datasets WHERE dataset_id = ?"
        ),
        params = list(vec_dataset_id_uniform)
      ) |>
      tibble::as_tibble()

    data_samples_classified <-
      data_samples_uniform |>
      dplyr::left_join(
        data_dataset_sample_uniform,
        by = dplyr::join_by(sample_id),
        relationship = "one-to-many"
      ) |>
      dplyr::left_join(
        data_datasets_uniform,
        by = dplyr::join_by(dataset_id),
        relationship = "many-to-one"
      )

    seconds_uniform_draw <-
      base::difftime(base::Sys.time(), time_step_start, units = "secs") |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.2. Links of a stratified draw of samples -----
    #--------------------------------------------------#

    time_step_start_links <-
      base::Sys.time()

    # One stratum per dataset type and source type; gridpoints (type 4)
    #   are the link targets and are handled in section 2.4
    data_samples_stratified <-
      data_samples_classified |>
      dplyr::filter(dataset_type_id != 4L) |>
      dplyr::slice_sample(
        n = n_samples_per_stratum,
        by = c(dataset_type_id, data_source_type_id)
      )

    vec_sample_id_stratified <-
      data_samples_stratified |>
      dplyr::pull(sample_id)

    data_links_stratified <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT sample_id, sample_ref_id, distance_in_km, ",
          "distance_in_years, typeof(distance_in_km) AS type_km, ",
          "typeof(distance_in_years) AS type_years ",
          "FROM AbioticDataReference WHERE sample_id = ?"
        ),
        params = list(vec_sample_id_stratified)
      ) |>
      tibble::as_tibble()

    seconds_stratified_links <-
      base::difftime(
        base::Sys.time(),
        time_step_start_links,
        units = "secs"
      ) |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.3. Cells and ages of the linked gridpoints -----
    #--------------------------------------------------#

    time_step_start_refs <-
      base::Sys.time()

    vec_sample_ref_id <-
      data_links_stratified |>
      dplyr::distinct(sample_ref_id) |>
      dplyr::pull(sample_ref_id)

    data_ref_samples <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT s.sample_id AS sample_ref_id, s.age AS ref_age, ",
          "d.dataset_id AS ref_dataset_id, ",
          "d.dataset_type_id AS ref_dataset_type_id, ",
          "d.coord_long AS ref_long, d.coord_lat AS ref_lat ",
          "FROM Samples s ",
          "JOIN DatasetSample ds ON ds.sample_id = s.sample_id ",
          "JOIN Datasets d ON d.dataset_id = ds.dataset_id ",
          "WHERE s.sample_id = ?"
        ),
        params = list(vec_sample_ref_id)
      ) |>
      tibble::as_tibble()

    seconds_linked_gridpoints <-
      base::difftime(
        base::Sys.time(),
        time_step_start_refs,
        units = "secs"
      ) |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.4. Gridpoint samples: reverse links and values -----
    #--------------------------------------------------#

    time_step_start_grid <-
      base::Sys.time()

    data_gridpoints_drawn <-
      data_samples_classified |>
      dplyr::filter(dataset_type_id == 4L) |>
      dplyr::slice_sample(n = n_samples_per_stratum)

    vec_sample_id_gridpoints <-
      data_gridpoints_drawn |>
      dplyr::pull(sample_id)

    # Index-only counts: no table row is read
    data_gridpoint_reverse_links <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT ? AS sample_id, count(*) AS n_samples_linking ",
          "FROM AbioticDataReference WHERE sample_ref_id = ?"
        ),
        params = list(vec_sample_id_gridpoints, vec_sample_id_gridpoints)
      ) |>
      tibble::as_tibble()

    data_gridpoint_values <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT ? AS sample_id, count(*) AS n_abiotic_values ",
          "FROM AbioticData WHERE sample_id = ?"
        ),
        params = list(vec_sample_id_gridpoints, vec_sample_id_gridpoints)
      ) |>
      tibble::as_tibble()

    seconds_gridpoint_samples <-
      base::difftime(
        base::Sys.time(),
        time_step_start_grid,
        units = "secs"
      ) |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.5. Spacing of the gridpoint cells -----
    #--------------------------------------------------#

    time_step_start_spacing <-
      base::Sys.time()

    data_cells_drawn <-
      data_gridpoints_drawn |>
      dplyr::distinct(dataset_id, coord_long, coord_lat) |>
      dplyr::slice_sample(n = n_gridpoint_cells_spacing)

    # Neighbouring gridpoint cells within half a degree; the range on
    #   coord_long uses idx_datasets_coord_long_lat
    data_cell_neighbours <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT ? AS dataset_id, coord_long AS nb_long, ",
          "coord_lat AS nb_lat FROM Datasets ",
          "INDEXED BY idx_datasets_coord_long_lat ",
          "WHERE coord_long BETWEEN ? AND ? ",
          "AND coord_lat BETWEEN ? AND ? AND dataset_type_id = 4"
        ),
        params = list(
          data_cells_drawn |>
            dplyr::pull(dataset_id),
          data_cells_drawn |>
            dplyr::pull(coord_long) - 0.5,
          data_cells_drawn |>
            dplyr::pull(coord_long) + 0.5,
          data_cells_drawn |>
            dplyr::pull(coord_lat) - 0.5,
          data_cells_drawn |>
            dplyr::pull(coord_lat) + 0.5
        )
      ) |>
      tibble::as_tibble()

    seconds_cell_spacing <-
      base::difftime(
        base::Sys.time(),
        time_step_start_spacing,
        units = "secs"
      ) |>
      base::as.numeric()

    #--------------------------------------------------#
    ## 2.6. Samples and ages per dataset -----
    #--------------------------------------------------#

    time_step_start_datasets <-
      base::Sys.time()

    vec_dataset_id_stratified <-
      data_samples_stratified |>
      dplyr::distinct(dataset_id) |>
      dplyr::pull(dataset_id)

    data_dataset_sample_counts <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT ? AS dataset_id, count(*) AS n_samples ",
          "FROM DatasetSample WHERE dataset_id = ?"
        ),
        params = list(vec_dataset_id_stratified, vec_dataset_id_stratified)
      ) |>
      tibble::as_tibble()

    # Distinct ages are counted only for datasets small enough to read
    vec_dataset_id_age_count <-
      data_dataset_sample_counts |>
      dplyr::filter(n_samples <= n_samples_max_for_age_count) |>
      dplyr::pull(dataset_id)

    data_dataset_age_counts <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT ? AS dataset_id, count(DISTINCT s.age) AS n_ages, ",
          "sum(s.age IS NULL) AS n_age_missing ",
          "FROM DatasetSample ds ",
          "JOIN Samples s ON s.sample_id = ds.sample_id ",
          "WHERE ds.dataset_id = ?"
        ),
        params = list(vec_dataset_id_age_count, vec_dataset_id_age_count)
      ) |>
      tibble::as_tibble()

    seconds_dataset_ages <-
      base::difftime(
        base::Sys.time(),
        time_step_start_datasets,
        units = "secs"
      ) |>
      base::as.numeric()
  },
  finally = DBI::dbDisconnect(con_v1)
)


#----------------------------------------------------------#
# 3. Record the file state after disconnecting -----
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


#----------------------------------------------------------#
# 4. Summarise -----
#----------------------------------------------------------#

#--------------------------------------------------#
## 4.1. Composition of samples -----
#--------------------------------------------------#

table_sample_composition <-
  data_samples_classified |>
  dplyr::summarise(
    n_drawn = dplyr::n(),
    n_age_missing = base::sum(base::is.na(age)),
    age_min = base::min(age, na.rm = TRUE),
    age_max = base::max(age, na.rm = TRUE),
    .by = c(dataset_type_id, data_source_type_id)
  ) |>
  dplyr::mutate(
    share = n_drawn / base::sum(n_drawn),
    # Normal approximation of the binomial standard error
    share_se = base::sqrt(share * (1 - share) / base::sum(n_drawn)),
    n_estimated = share * n_samples_total,
    n_estimated_lwr_95 = (share - 1.96 * share_se) * n_samples_total,
    n_estimated_upr_95 = (share + 1.96 * share_se) * n_samples_total
  ) |>
  dplyr::arrange(dataset_type_id, data_source_type_id)

#--------------------------------------------------#
## 4.2. Links per sample -----
#--------------------------------------------------#

data_links_with_refs <-
  data_links_stratified |>
  dplyr::left_join(
    data_ref_samples,
    by = dplyr::join_by(sample_ref_id),
    relationship = "many-to-one"
  )

data_links_per_sample <-
  data_samples_stratified |>
  dplyr::select(
    sample_id, dataset_type_id, data_source_type_id, age
  ) |>
  dplyr::left_join(
    data_links_with_refs |>
      dplyr::summarise(
        n_links = dplyr::n(),
        n_cells = dplyr::n_distinct(ref_long, ref_lat),
        n_ages = dplyr::n_distinct(ref_age),
        km_min = base::min(distance_in_km),
        km_max = base::max(distance_in_km),
        years_max = base::max(distance_in_years),
        n_ref_not_gridpoint = base::sum(ref_dataset_type_id != 4L),
        .by = sample_id
      ),
    by = dplyr::join_by(sample_id),
    relationship = "one-to-one"
  ) |>
  dplyr::mutate(
    n_links = dplyr::coalesce(n_links, 0L)
  )

table_links_per_stratum <-
  data_links_per_sample |>
  dplyr::summarise(
    n_samples_drawn = dplyr::n(),
    share_without_links = base::mean(n_links == 0L),
    links_mean = base::mean(n_links),
    links_median = stats::median(n_links),
    links_upr_95 = stats::quantile(n_links, probs = 0.975),
    links_max = base::max(n_links),
    cells_median = stats::median(n_cells, na.rm = TRUE),
    cells_max = base::max(n_cells, na.rm = TRUE),
    ages_median = stats::median(n_ages, na.rm = TRUE),
    ages_max = base::max(n_ages, na.rm = TRUE),
    km_max = base::max(km_max, na.rm = TRUE),
    years_max = base::max(years_max, na.rm = TRUE),
    n_ref_not_gridpoint = base::sum(n_ref_not_gridpoint, na.rm = TRUE),
    .by = c(dataset_type_id, data_source_type_id)
  ) |>
  dplyr::arrange(dataset_type_id, data_source_type_id)

table_distance_types <-
  data_links_stratified |>
  dplyr::count(type_km, type_years, name = "n_links") |>
  dplyr::mutate(
    n_km_fractional = base::sum(
      data_links_stratified |>
        dplyr::pull(distance_in_km) %% 1 != 0,
      na.rm = TRUE
    ),
    n_years_fractional = base::sum(
      data_links_stratified |>
        dplyr::pull(distance_in_years) %% 1 != 0,
      na.rm = TRUE
    )
  )

#--------------------------------------------------#
## 4.3. Gridpoint samples -----
#--------------------------------------------------#

table_gridpoint_samples <-
  data_gridpoints_drawn |>
  dplyr::select(sample_id, age) |>
  dplyr::left_join(
    data_gridpoint_reverse_links,
    by = dplyr::join_by(sample_id),
    relationship = "one-to-one"
  ) |>
  dplyr::left_join(
    data_gridpoint_values,
    by = dplyr::join_by(sample_id),
    relationship = "one-to-one"
  ) |>
  dplyr::summarise(
    n_drawn = dplyr::n(),
    share_not_linked = base::mean(n_samples_linking == 0L),
    linking_median = stats::median(n_samples_linking),
    linking_max = base::max(n_samples_linking),
    share_without_values = base::mean(n_abiotic_values == 0L),
    values_median = stats::median(n_abiotic_values),
    values_max = base::max(n_abiotic_values),
    n_distinct_ages_drawn = dplyr::n_distinct(age)
  )

table_gridpoint_ages <-
  data_ref_samples |>
  dplyr::filter(ref_dataset_type_id == 4L) |>
  dplyr::bind_rows(
    data_gridpoints_drawn |>
      dplyr::select(ref_age = age)
  ) |>
  dplyr::distinct(ref_age) |>
  dplyr::arrange(ref_age)

table_cell_spacing <-
  data_cell_neighbours |>
  dplyr::left_join(
    data_cells_drawn,
    by = dplyr::join_by(dataset_id),
    relationship = "many-to-one"
  ) |>
  dplyr::mutate(
    d_long = base::abs(nb_long - coord_long),
    d_lat = base::abs(nb_lat - coord_lat)
  ) |>
  dplyr::summarise(
    spacing_long = base::min(
      d_long[d_long > 1e-9 & d_lat < 1e-9],
      Inf
    ),
    spacing_lat = base::min(
      d_lat[d_lat > 1e-9 & d_long < 1e-9],
      Inf
    ),
    .by = dataset_id
  ) |>
  dplyr::filter(
    base::is.finite(spacing_long) | base::is.finite(spacing_lat)
  ) |>
  dplyr::count(spacing_long, spacing_lat, name = "n_cells")

#--------------------------------------------------#
## 4.4. Samples and ages per dataset -----
#--------------------------------------------------#

table_dataset_ages <-
  data_samples_stratified |>
  dplyr::distinct(dataset_id, dataset_type_id, data_source_type_id) |>
  dplyr::left_join(
    data_dataset_sample_counts,
    by = dplyr::join_by(dataset_id),
    relationship = "one-to-one"
  ) |>
  dplyr::left_join(
    data_dataset_age_counts,
    by = dplyr::join_by(dataset_id),
    relationship = "one-to-one"
  ) |>
  dplyr::summarise(
    n_datasets_drawn = dplyr::n(),
    n_datasets_ages_counted = base::sum(!base::is.na(n_ages)),
    samples_per_dataset_median = stats::median(n_samples),
    samples_per_dataset_max = base::max(n_samples),
    ages_per_dataset_median = stats::median(n_ages, na.rm = TRUE),
    samples_per_age_median = stats::median(
      n_samples / base::pmax(n_ages, 1L),
      na.rm = TRUE
    ),
    .by = c(dataset_type_id, data_source_type_id)
  ) |>
  dplyr::arrange(dataset_type_id, data_source_type_id)


#----------------------------------------------------------#
# 5. Save results -----
#----------------------------------------------------------#

data_run_info <-
  tibble::tibble(
    script = "02_sample_v1_link_structure.R",
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    seed = 1234L,
    n_samples_total = n_samples_total,
    n_samples_uniform = n_samples_uniform,
    n_samples_per_stratum = n_samples_per_stratum,
    n_links_read = base::nrow(data_links_stratified),
    n_gridpoint_refs_read = base::nrow(data_ref_samples),
    connection_flags = "SQLITE_RO",
    file_unchanged = flag_file_unchanged
  )

data_step_seconds <-
  tibble::tibble(
    step = c(
      "uniform_draw",
      "stratified_links",
      "linked_gridpoints",
      "gridpoint_samples",
      "cell_spacing",
      "dataset_ages"
    ),
    seconds = c(
      seconds_uniform_draw,
      seconds_stratified_links,
      seconds_linked_gridpoints,
      seconds_gridpoint_samples,
      seconds_cell_spacing,
      seconds_dataset_ages
    )
  )

list_outputs <-
  list(
    run_info = data_run_info,
    step_seconds = data_step_seconds,
    sample_composition = table_sample_composition,
    links_per_stratum = table_links_per_stratum,
    distance_types = table_distance_types,
    gridpoint_samples = table_gridpoint_samples,
    gridpoint_ages = table_gridpoint_ages,
    cell_spacing = table_cell_spacing,
    dataset_ages = table_dataset_ages,
    links_per_sample = data_links_per_sample
  )

purrr::iwalk(
  .x = list_outputs,
  .f = ~ readr::write_csv(
    x = .x,
    file = base::file.path(path_output, stringr::str_c(.y, ".csv"))
  )
)


#----------------------------------------------------------#
# 6. Check that the file was not changed -----
#----------------------------------------------------------#

if (
  base::isFALSE(flag_file_unchanged)
) {
  cli::cli_abort(
    "The database file differs after the read-only session."
  )
}

cli::cli_inform(
  c(
    "v" = "Read-only session finished; the file is unchanged.",
    "i" = "Results saved to {.path Data/Temp/Database_research}."
  )
)
