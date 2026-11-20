#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Project the sizes of the schema prototypes to v1.0.0
#                 - from saved results only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Project the size of each schema variant built on the regional subset by
#   13_build_schema_prototypes.R to the content of v1.0.0. No database is
#   opened; the script reads saved results only:
#   - the object sizes of the variants (13, `dbstat` on the subset builds);
#   - the object sizes and row counts of v1.0.0 (06_scan_v1_full.R and
#     01_inspect_v1_metadata.R);
#   - the positions and position links of v1.0.0
#     (15_check_v1_schema_candidates.R).
# Two methods:
#   - Ratio, for every table with its indexes except the link tables: the
#     measured v1.0.0 size of the table times the ratio of its size in the
#     variant to its size in the `v1` variant on the subset. For the `v1`
#     variant this returns the measured v1.0.0 size.
#   - Per row, for the link tables: bytes per row on the subset times the
#     v1.0.0 count (links, or positions, mapped samples and position links).
#     The per-row projection of the v1 link table is compared with its
#     measured size, as a check of the method.
# The `gridpoint_tables` variant moves rows between tables, so the ratio
#   method does not apply to it; it is left out.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/16_project_schema_sizes.R
#     <run folder of script 13> <run folder of script 15>


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 2L,
  base::all(stringr::str_detect(vec_args, "^run_[0-9_]+$")),
  msg = "Give the run folders of scripts 13 and 15."
)

path_research <-
  here::here("Data", "Temp", "Database_research")

path_prototypes <-
  base::file.path(path_research, "Prototypes", purrr::chuck(vec_args, 1L))

path_v1_checks <-
  base::file.path(
    path_research, "V1_schema_checks", purrr::chuck(vec_args, 2L)
  )

assertthat::assert_that(
  base::dir.exists(path_prototypes),
  base::dir.exists(path_v1_checks),
  msg = "A run folder does not exist."
)

vec_link_tables <-
  c("AbioticDataReference", "Positions", "SamplePosition", "PositionLink")

# vroom crashes on some of these files with several threads
data_object_sizes <-
  readr::read_csv(
    file = base::file.path(path_prototypes, "object_sizes.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_v1_dbstat <-
  readr::read_csv(
    file = base::file.path(
      path_research, "V1_full_scans", "dbstat_by_object.csv"
    ),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_v1_rows <-
  readr::read_csv(
    file = base::file.path(path_research, "V1_metadata", "rowid_bounds.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_build_statements <-
  readr::read_csv(
    file = base::file.path(path_prototypes, "build_statements.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_position_links <-
  readr::read_csv(
    file = base::file.path(path_v1_checks, "position_link_counts.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )

data_position_sizes <-
  readr::read_csv(
    file = base::file.path(path_v1_checks, "position_sizes.csv"),
    show_col_types = FALSE,
    num_threads = 1L
  )


#----------------------------------------------------------#
# 1. Counts -----
#----------------------------------------------------------#

# v1.0.0: the maximum rowid of each table equals its row count
#   (01_inspect_v1_metadata.R, confirmed by 06_scan_v1_full.R)
n_v1_links <-
  data_v1_rows |>
  dplyr::filter(table_name == "AbioticDataReference") |>
  dplyr::pull(max_rowid)

n_v1_positions <-
  data_position_sizes |>
  dplyr::pull(n_positions) |>
  base::sum()

n_v1_mapped_samples <-
  data_position_sizes |>
  dplyr::summarise(n = base::sum(n_samples * n_positions)) |>
  dplyr::pull(n)

n_v1_position_links <-
  data_position_links |>
  dplyr::summarise(n = base::sum(n_links * n_positions)) |>
  dplyr::pull(n)

# Subset: rows loaded into the position tables, and links of the subset
data_subset_rows <-
  data_build_statements |>
  dplyr::filter(
    variant == "tuple_links",
    repetition == base::max(repetition),
    kind == "load",
    object %in% c("Positions", "SamplePosition", "PositionLink")
  ) |>
  dplyr::select(object, n_rows)

n_subset_links <-
  data_build_statements |>
  dplyr::filter(
    variant == "v1",
    repetition == base::max(repetition),
    kind == "copy",
    object == "AbioticDataReference"
  ) |>
  dplyr::pull(n_rows)

data_counts <-
  tibble::tibble(
    table_name = c(
      "AbioticDataReference", "Positions", "SamplePosition", "PositionLink"
    ),
    n_rows_subset = c(
      n_subset_links,
      data_subset_rows |>
        dplyr::filter(object == "Positions") |>
        dplyr::pull(n_rows),
      data_subset_rows |>
        dplyr::filter(object == "SamplePosition") |>
        dplyr::pull(n_rows),
      data_subset_rows |>
        dplyr::filter(object == "PositionLink") |>
        dplyr::pull(n_rows)
    ),
    n_rows_v1 = c(
      n_v1_links,
      n_v1_positions,
      n_v1_mapped_samples,
      n_v1_position_links
    )
  )

readr::write_csv(
  x = data_counts,
  file = base::file.path(path_prototypes, "size_projection_counts.csv")
)


#----------------------------------------------------------#
# 2. Project -----
#----------------------------------------------------------#

# Bytes of each table with its indexes, per variant, on the subset
data_table_bytes <-
  data_object_sizes |>
  dplyr::filter(variant != "gridpoint_tables") |>
  dplyr::summarise(
    bytes_subset = base::sum(bytes),
    .by = c(variant, table_name)
  )

# v1.0.0 bytes of each table with its indexes; objects are matched to
#   their table through the `v1` variant, which has the same object names
data_v1_table_bytes <-
  data_v1_dbstat |>
  dplyr::left_join(
    data_object_sizes |>
      dplyr::filter(variant == "v1") |>
      dplyr::distinct(object, table_name),
    by = c("name" = "object")
  ) |>
  dplyr::mutate(table_name = dplyr::coalesce(table_name, name)) |>
  dplyr::summarise(bytes_v1 = base::sum(bytes), .by = table_name)

data_projection_by_table <-
  data_table_bytes |>
  dplyr::left_join(
    data_table_bytes |>
      dplyr::filter(variant == "v1") |>
      dplyr::select(table_name, bytes_subset_v1 = bytes_subset),
    by = "table_name"
  ) |>
  dplyr::left_join(data_v1_table_bytes, by = "table_name") |>
  dplyr::left_join(data_counts, by = "table_name") |>
  dplyr::mutate(
    flag_link_table = table_name %in% vec_link_tables,
    method = dplyr::if_else(flag_link_table, "per_row", "ratio"),
    bytes_projected = dplyr::if_else(
      condition = flag_link_table,
      true = bytes_subset / n_rows_subset * n_rows_v1,
      false = bytes_v1 * bytes_subset / bytes_subset_v1
    )
  )

assertthat::assert_that(
  !base::anyNA(data_projection_by_table |> dplyr::pull(bytes_projected)),
  msg = "A table could not be projected."
)

readr::write_csv(
  x = data_projection_by_table,
  file = base::file.path(path_prototypes, "size_projection_by_table.csv")
)

# The per-row method on the v1 link table, against its measured size
bytes_v1_links_measured <-
  data_v1_table_bytes |>
  dplyr::filter(table_name == "AbioticDataReference") |>
  dplyr::pull(bytes_v1)

bytes_v1_links_per_row <-
  data_projection_by_table |>
  dplyr::filter(variant == "v1", table_name == "AbioticDataReference") |>
  dplyr::pull(bytes_projected)

data_projection <-
  data_projection_by_table |>
  dplyr::summarise(
    gb_links = base::sum(bytes_projected[flag_link_table]) / 1e9,
    gb_other = base::sum(bytes_projected[!flag_link_table]) / 1e9,
    .by = variant
  ) |>
  dplyr::mutate(
    gb_total = gb_links + gb_other,
    # The link tables of v1 layouts by ratio instead of per row
    gb_links_ratio = dplyr::if_else(
      condition = variant %in% c(
        "v1", "no_pk_duplicates", "lean_indexes", "without_rowid"
      ),
      true = gb_links * bytes_v1_links_measured / bytes_v1_links_per_row,
      false = NA_real_
    ),
    ratio_v1_links_measured_to_per_row =
      bytes_v1_links_measured / bytes_v1_links_per_row
  )

readr::write_csv(
  x = data_projection,
  file = base::file.path(path_prototypes, "size_projection.csv")
)

cli::cli_inform(
  c(
    "v" = "Projected the variant sizes to v1.0.0.",
    "i" = "Results in {.path {path_prototypes}}."
  )
)
