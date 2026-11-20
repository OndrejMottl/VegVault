#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Compare the 2.0.0 links of the benchmark with v1
#             - saved research files, read-only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Compare the links that the build-engine benchmark computed with the 2.0.0
#   rule (17a_run_build_engine.R) with the v1 links of the same positions,
#   on the regional subset:
#   - the v1 links per position are those of the `tuple_links` prototype
#     of 13_build_schema_prototypes.R, whose positions are numbered in the
#     same order; their gridpoints are matched by coordinates and age
#     (from the subset);
#   - every v1 link should be found with the same km and years;
#   - links found only with the 2.0.0 rule are described by why v1 missed
#     them: a longitude difference above 1 degree (the v1 fine window) or a
#     position near the dateline, or another reason.
# All files are opened read-only; nothing is written to them.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/19_compare_links_with_v1.R
#     <run folder of script 17> <run folder of script 13>


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 2L,
  base::all(stringr::str_detect(vec_args, "^run_[0-9_]+$")),
  msg = "Give the run folders of scripts 17 and 13."
)

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

path_research <-
  here::here("Data", "Temp", "Database_research")

path_engines <-
  base::file.path(path_research, "Engines", purrr::chuck(vec_args, 1L))

path_new <-
  base::file.path(path_engines, "r_memory_rep1.sqlite")

path_v1_links <-
  base::file.path(
    path_research, "Prototypes", purrr::chuck(vec_args, 2L),
    "tuple_links.sqlite"
  )

path_subset <-
  base::file.path(
    path_research,
    "Subset",
    stringr::str_c(
      "v1_subset_",
      purrr::chuck(list_settings, "subset", "box_name"),
      ".sqlite"
    )
  )

assertthat::assert_that(
  base::file.exists(path_new),
  base::file.exists(path_v1_links),
  base::file.exists(path_subset),
  msg = "An input file is missing."
)

# The v1 fine window: +-1 degree of longitude (half the 2-degree grid)
value_v1_window_deg <-
  purrr::chuck(list_settings, "profiling", "grid_size_degree") / 2


#----------------------------------------------------------#
# 1. Read both link sets -----
#----------------------------------------------------------#

con_new <-
  DBI::dbConnect(RSQLite::SQLite(), path_new, flags = RSQLite::SQLITE_RO)

data_links_new <-
  DBI::dbGetQuery(
    con_new,
    stringr::str_c(
      "SELECT l.position_id, p.coord_long, p.coord_lat, p.age, ",
      "g.coord_long AS grid_long, g.coord_lat AS grid_lat, ",
      "g.age AS grid_age, l.distance_in_km, l.distance_in_years ",
      "FROM PositionLink AS l ",
      "JOIN Positions AS p ON p.position_id = l.position_id ",
      "JOIN Gridpoints AS g ON g.gridpoint_id = l.gridpoint_id"
    )
  ) |>
  tibble::as_tibble()

DBI::dbDisconnect(con_new)

con_v1 <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_v1_links,
    flags = RSQLite::SQLITE_RO
  )

DBI::dbExecute(
  con_v1,
  "ATTACH DATABASE ? AS src",
  params = list(
    stringr::str_c(
      "file:",
      base::normalizePath(path_subset, winslash = "/"),
      "?mode=ro"
    )
  )
)

data_links_v1 <-
  DBI::dbGetQuery(
    con_v1,
    stringr::str_c(
      "SELECT l.position_id, p.coord_long, p.coord_lat, p.age, ",
      "d.coord_long AS grid_long, d.coord_lat AS grid_lat, ",
      "s.age AS grid_age, l.distance_in_km, l.distance_in_years ",
      "FROM main.PositionLink AS l ",
      "JOIN main.Positions AS p ON p.position_id = l.position_id ",
      "JOIN src.Samples AS s ON s.sample_id = l.sample_ref_id ",
      "JOIN src.DatasetSample AS ds ON ds.sample_id = s.sample_id ",
      "JOIN src.Datasets AS d ON d.dataset_id = ds.dataset_id"
    )
  ) |>
  tibble::as_tibble()

DBI::dbDisconnect(con_v1)


#----------------------------------------------------------#
# 2. Compare -----
#----------------------------------------------------------#

vec_keys <-
  c("coord_long", "coord_lat", "age", "grid_long", "grid_lat", "grid_age")

data_matched <-
  data_links_v1 |>
  dplyr::left_join(
    data_links_new |>
      dplyr::select(
        dplyr::all_of(vec_keys),
        km_new = distance_in_km,
        years_new = distance_in_years
      ),
    by = vec_keys,
    multiple = "error"
  )

data_new_only <-
  data_links_new |>
  dplyr::anti_join(data_links_v1, by = vec_keys) |>
  dplyr::mutate(
    longitude_difference = base::abs(coord_long - grid_long),
    reason = dplyr::case_when(
      longitude_difference > 180 ~ "across the dateline",
      longitude_difference > value_v1_window_deg ~
        "longitude difference above the v1 window",
      .default = "other"
    )
  )

data_summary <-
  tibble::tibble(
    n_links_v1 = base::nrow(data_links_v1),
    n_links_new = base::nrow(data_links_new),
    n_v1_found = data_matched |>
      dplyr::filter(!base::is.na(km_new)) |>
      base::nrow(),
    n_v1_found_same_km_years = data_matched |>
      dplyr::filter(
        km_new == distance_in_km,
        years_new == distance_in_years
      ) |>
      base::nrow(),
    n_new_only = base::nrow(data_new_only),
    n_positions_with_new_links = data_new_only |>
      dplyr::distinct(position_id) |>
      base::nrow(),
    min_latitude_new_only = base::min(
      data_new_only |> dplyr::pull(coord_lat)
    )
  )

readr::write_csv(
  x = data_summary,
  file = base::file.path(path_engines, "links_against_v1.csv")
)

data_new_only |>
  dplyr::count(reason, name = "n_links") |>
  readr::write_csv(
    file = base::file.path(path_engines, "links_new_only_reasons.csv")
  )

cli::cli_inform(
  c(
    "v" = "Compared the 2.0.0 links with v1.",
    "i" = "Results in {.path {path_engines}}."
  )
)
