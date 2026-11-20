#----------------------------------------------------------#
#
#
#                       VegVault
#
#       Count v1.0.0 content in candidate subset boxes
#             - primary-key and index lookups only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Count datasets, samples, and (estimated) gridpoint links of the v1.0.0
#   database inside candidate bounding boxes, to choose the regional subset
#   for the build prototypes. The subset must hold every source type and
#   land north of 63.3 degrees, where the v1 +-1 degree longitude window is
#   narrower than 50 km. Every query is a range on the coordinate index or
#   a lookup on one key value. The file is opened read-only, and its size,
#   modification time, and header are compared before and after.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (resolves `path_to_vegvault` from the secrets file)
source(
  here::here("R/00_Config_file.R")
)

path_output <-
  here::here("Data", "Temp", "Database_research", "V1_candidate_boxes")

base::dir.create(
  path = path_output,
  recursive = TRUE,
  showWarnings = FALSE
)

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

# Candidate boxes in degrees (WGS84); none crosses the dateline
data_boxes <-
  tibble::tribble(
    ~box_name, ~lon_min, ~lon_max, ~lat_min, ~lat_max,
    "fennoscandia", 4, 32, 54, 71.5,
    "scandinavian_mountains", 5, 20, 60, 70,
    "northern_europe", -25, 45, 50, 72,
    "alaska_yukon", -170, -125, 54, 72,
    "western_north_america", -170, -110, 40, 72
  )

# Latitude above which the v1 longitude window is narrower than 50 km
lat_window_too_narrow <- 63.3

# Links are counted on a random draw of samples per box and scaled up
n_samples_link_draw <- 5000L

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
    ## 2.1. Datasets inside each box -----
    #--------------------------------------------------#

    data_box_datasets <-
      data_boxes |>
      dplyr::mutate(
        datasets = purrr::pmap(
          .l = list(lon_min, lon_max, lat_min, lat_max),
          .f = ~ DBI::dbGetQuery(
            conn = con_v1,
            statement = stringr::str_c(
              "SELECT dataset_id, dataset_type_id, data_source_type_id, ",
              "coord_long, coord_lat FROM Datasets ",
              "INDEXED BY idx_datasets_coord_long_lat ",
              "WHERE coord_long BETWEEN ? AND ? ",
              "AND coord_lat BETWEEN ? AND ?"
            ),
            params = list(..1, ..2, ..3, ..4)
          ) |>
            tibble::as_tibble()
        )
      ) |>
      dplyr::select(box_name, datasets) |>
      tidyr::unnest(cols = datasets)

    #--------------------------------------------------#
    ## 2.2. Samples per dataset (index-only counts) -----
    #--------------------------------------------------#

    vec_dataset_id_boxes <-
      data_box_datasets |>
      dplyr::distinct(dataset_id) |>
      dplyr::pull(dataset_id)

    data_dataset_sample_counts <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT ? AS dataset_id, count(*) AS n_samples ",
          "FROM DatasetSample WHERE dataset_id = ?"
        ),
        params = list(vec_dataset_id_boxes, vec_dataset_id_boxes)
      ) |>
      tibble::as_tibble()

    #--------------------------------------------------#
    ## 2.3. Links of a random draw of samples per box -----
    #--------------------------------------------------#

    vec_dataset_id_not_gridpoint <-
      data_box_datasets |>
      dplyr::filter(dataset_type_id != 4L) |>
      dplyr::distinct(dataset_id) |>
      dplyr::pull(dataset_id)

    data_box_sample_ids <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT dataset_id, sample_id FROM DatasetSample ",
          "WHERE dataset_id = ?"
        ),
        params = list(vec_dataset_id_not_gridpoint)
      ) |>
      tibble::as_tibble()

    data_box_samples_drawn <-
      data_box_datasets |>
      dplyr::filter(dataset_type_id != 4L) |>
      dplyr::select(box_name, dataset_id, dataset_type_id) |>
      # Boxes overlap, so a dataset can appear once per box
      dplyr::inner_join(
        data_box_sample_ids,
        by = dplyr::join_by(dataset_id),
        relationship = "many-to-many"
      ) |>
      dplyr::slice_sample(
        n = n_samples_link_draw,
        by = c(box_name, dataset_type_id)
      )

    vec_sample_id_drawn <-
      data_box_samples_drawn |>
      dplyr::distinct(sample_id) |>
      dplyr::pull(sample_id)

    # Index-only counts: no table row is read
    data_sample_link_counts <-
      DBI::dbGetQuery(
        conn = con_v1,
        statement = stringr::str_c(
          "SELECT ? AS sample_id, count(*) AS n_links ",
          "FROM AbioticDataReference WHERE sample_id = ?"
        ),
        params = list(vec_sample_id_drawn, vec_sample_id_drawn)
      ) |>
      tibble::as_tibble()
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
# 4. Summarise per box -----
#----------------------------------------------------------#

table_box_content <-
  data_box_datasets |>
  dplyr::left_join(
    data_dataset_sample_counts,
    by = dplyr::join_by(dataset_id),
    relationship = "many-to-one"
  ) |>
  # `n_samples_north` comes before `n_samples`, because summarise() lets
  #   later expressions see the already summarised column
  dplyr::summarise(
    n_datasets = dplyr::n(),
    n_datasets_north = base::sum(coord_lat > lat_window_too_narrow),
    n_samples_north = base::sum(
      n_samples[coord_lat > lat_window_too_narrow]
    ),
    n_samples = base::sum(n_samples),
    .by = c(box_name, dataset_type_id, data_source_type_id)
  ) |>
  dplyr::arrange(box_name, dataset_type_id, data_source_type_id)

table_box_links <-
  data_box_samples_drawn |>
  dplyr::left_join(
    data_sample_link_counts,
    by = dplyr::join_by(sample_id),
    relationship = "many-to-one"
  ) |>
  dplyr::summarise(
    n_samples_drawn = dplyr::n(),
    links_mean = base::mean(n_links),
    .by = c(box_name, dataset_type_id)
  ) |>
  dplyr::left_join(
    table_box_content |>
      dplyr::summarise(
        n_samples = base::sum(n_samples),
        .by = c(box_name, dataset_type_id)
      ),
    by = dplyr::join_by(box_name, dataset_type_id),
    relationship = "one-to-one"
  ) |>
  dplyr::mutate(
    n_links_estimated = links_mean * n_samples
  ) |>
  dplyr::arrange(box_name, dataset_type_id)


#----------------------------------------------------------#
# 5. Save results -----
#----------------------------------------------------------#

data_run_info <-
  tibble::tibble(
    script = "03_count_v1_candidate_boxes.R",
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    seed = 1234L,
    n_samples_link_draw = n_samples_link_draw,
    connection_flags = "SQLITE_RO",
    file_unchanged = flag_file_unchanged
  )

list_outputs <-
  list(
    run_info = data_run_info,
    boxes = data_boxes,
    box_content = table_box_content,
    box_links = table_box_links
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
