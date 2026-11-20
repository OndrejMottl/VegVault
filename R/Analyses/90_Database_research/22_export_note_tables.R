#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Export the summary tables behind the design note
#                 - from saved results only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Copy the summary tables that the numbers of
#   Documentation/Database_design_2.0.0.md come from out of the git-ignored
#   research folder (Data/Temp/Database_research) into a tracked folder
#   next to the note, one subfolder per question, and write a README that
#   names the script and run of every file:
#   - only the runs the note cites (`note_tables: runs` in
#     research_settings.yml) and only listed files are exported: counts,
#     sizes, timings and distributions, never row-level content of
#     v1.0.0, statement logs or trace events;
#   - tables of repeated runs (the vaultkeepr workloads on each prototype,
#     the chunk-size runs) are combined into one table each;
#   - columns that hold local paths are dropped, and every exported file is
#     scanned for path-like text afterwards; the export stops if any is
#     found.
# No database is opened. The target folder must not exist; delete it on
#   purpose to export again.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/22_export_note_tables.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

list_settings_note <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  ) |>
  purrr::chuck("note_tables")

list_runs <-
  purrr::chuck(list_settings_note, "runs")

path_research <-
  here::here("Data", "Temp", "Database_research")

path_target <-
  here::here(purrr::chuck(list_settings_note, "target_dir"))

assertthat::assert_that(
  !base::dir.exists(path_target),
  msg = "The target folder exists; delete it on purpose to export again."
)

# Columns never exported, because they hold local paths
vec_columns_dropped <-
  c("temp_dir", "path", "path_output", "path_log_prefix")

# Text that looks like a local path
pattern_path <-
  "[A-Za-z]:[/\\\\]|Users[/\\\\]"


#----------------------------------------------------------#
# 1. The files -----
#----------------------------------------------------------#

# One row per file: question folder, source folder (relative to the
#   research folder), file name, and the script that wrote it
data_files <-
  tibble::tribble(
    ~question, ~source, ~script, ~files,
    "q1_v1_content", "V1_metadata", "01_inspect_v1_metadata.R",
    c(
      "file_state", "header_fields", "pragmas", "rowid_bounds",
      "schema_comparison", "version_control", "dataset_type",
      "dataset_source_type", "abiotic_variable"
    ),
    "q1_v1_content", "V1_link_sample", "02_sample_v1_link_structure.R",
    c(
      "links_per_stratum", "cell_spacing", "gridpoint_ages",
      "gridpoint_samples", "dataset_ages", "distance_types",
      "sample_composition", "step_seconds"
    ),
    "q1_v1_content", "V1_candidate_boxes", "03_count_v1_candidate_boxes.R",
    c("boxes", "box_content", "box_links", "run_info"),
    "q1_v1_content", "V1_subset_extraction", "04_extract_v1_subset.R",
    c("subset_row_counts", "step_seconds", "subset_foreign_key_check"),
    "q1_v1_content", "Scan_calibration", "05_calibrate_scan_rates.R",
    c("scan_rates", "scan_runs", "run_info"),
    "q1_v1_content", "V1_full_scans", "06_scan_v1_full.R",
    c(
      "dbstat_by_object", "dataset_composition", "sample_composition",
      "tuples_all_sources", "tuples_per_source", "links_per_sample",
      "links_per_gridpoint", "link_distance_types",
      "duplicate_sample_names", "duplicate_dataset_names",
      "foreign_key_check", "gridpoint_ages", "samples_without_links",
      "trait_samples_without_value", "trait_values_per_sample",
      "abiotic_values_per_variable",
      "gridpoint_samples_without_values_or_links",
      "seconds_dbstat_by_object", "seconds_foreign_key_check",
      "seconds_link_distance_types", "seconds_links_per_sample",
      "seconds_tuples_all_sources", "seconds_sample_composition"
    ),
    "q2_v1_build", purrr::chuck(list_runs, "profiling_kenai"),
    "08_profile_v1_gridpoints.R",
    c(
      "step_summary", "trace_steps", "rprof_by_self", "rprof_by_total",
      "validation_links", "run_info"
    ),
    "q2_v1_build", purrr::chuck(list_runs, "profiling_core"),
    "08_profile_v1_gridpoints.R",
    c(
      "step_summary", "trace_steps", "rprof_by_self", "rprof_by_total",
      "validation_links", "run_info"
    ),
    "q2_v1_build", purrr::chuck(list_runs, "profiling_full_box"),
    "08_profile_v1_gridpoints.R",
    c(
      "step_summary", "trace_steps", "rprof_by_self", "rprof_by_total",
      "validation_links", "run_info"
    ),
    "q2_v1_build", purrr::chuck(list_runs, "profiling_global"),
    "09_profile_v1_global_batches.R",
    c(
      "batch_runs", "link_agreement", "step_summary", "trace_steps",
      "run_info"
    ),
    "q2_v1_build", purrr::chuck(list_runs, "profiling_writes"),
    "10_benchmark_link_writes.R",
    c(
      "in_query_runs", "read_runs", "write_batches", "write_summary",
      "run_info"
    ),
    "q2_v1_build", "V1_extrapolation", "11_extrapolate_v1_gridpoint_stage.R",
    c(
      "stage06_terms", "stage06_inputs", "stage06_write_alternative",
      "box_batches", "global_coarse"
    ),
    "q3_vaultkeepr", purrr::chuck(list_runs, "vaultkeepr_v1"),
    "12_profile_vaultkeepr_queries.R",
    c(
      "workload_summary", "index_usage", "table_scans", "run_info",
      "vaultkeepr_info"
    ),
    "q4_schema", purrr::chuck(list_runs, "prototypes"),
    "13_build_schema_prototypes.R and 16_project_schema_sizes.R",
    c(
      "build_summary", "build_files", "content_checks", "schema_checks",
      "object_sizes", "type_probe_checks", "type_probe_sizes",
      "size_projection", "size_projection_by_table",
      "size_projection_counts", "run_info"
    ),
    "q4_schema", purrr::chuck(list_runs, "prototype_queries"),
    "14_query_schema_prototypes.R",
    c("query_summary", "version_probe", "run_info"),
    "q4_schema", purrr::chuck(list_runs, "v1_schema_checks"),
    "15_check_v1_schema_candidates.R",
    c(
      "key_duplicates", "sample_taxa_duplicates_by_source",
      "ages_by_dataset_type", "coordinates_out_of_range",
      "mandatory_values", "gridpoint_references", "gridpoint_columns",
      "position_link_counts", "position_sizes", "link_set_draw",
      "link_set_draw_summary", "step_seconds", "run_info"
    ),
    "q5_engines", purrr::chuck(list_runs, "engines"),
    stringr::str_c(
      "17_benchmark_build_engines.R, 18_extrapolate_build_engines.R and ",
      "19_compare_links_with_v1.R"
    ),
    c(
      "engine_summary", "steps", "memory", "run_status", "comparison",
      "extrapolation_counts", "extrapolation_steps", "extrapolation_totals",
      "links_against_v1", "links_new_only_reasons", "distance_check",
      "duckdb_versions", "run_info"
    ),
    "q5_engines", purrr::chuck(list_runs, "full_links_v1"),
    "20_run_full_size_links.R",
    c(
      "counts", "steps", "compare_with_v1_by_stratum",
      "links_by_latitude_band", "links_per_position",
      "v1_links_not_reproduced", "new_links_other_reason", "run_info"
    )
  )

if (
  "bulk_load" %in% base::names(list_runs)
) {
  data_files <-
    data_files |>
    dplyr::bind_rows(
      tibble::tribble(
        ~question, ~source, ~script, ~files,
        "q6_bulk_load", purrr::chuck(list_runs, "bulk_load"),
        "21_benchmark_bulk_load.R",
        c(
          "variant_summary", "steps", "files", "analyze", "vacuum",
          "checksums", "compression", "source_info", "run_status",
          "run_info"
        )
      )
    )
}

# Runs of the settings are named by their key, other folders by their name
data_run_keys <-
  tibble::tibble(
    source = base::unlist(list_runs) |>
      base::unname(),
    run_key = base::names(list_runs)
  )

data_files <-
  data_files |>
  tidyr::unnest(files) |>
  dplyr::rename(file_name = files) |>
  dplyr::left_join(data_run_keys, by = "source") |>
  dplyr::mutate(
    path_source = base::file.path(
      path_research, source, stringr::str_c(file_name, ".csv")
    ),
    # Unique names inside each question folder: the run, then the file
    name_out = stringr::str_c(
      dplyr::coalesce(run_key, base::basename(source)),
      "__", file_name, ".csv"
    ),
    path_out = base::file.path(path_target, question, name_out)
  ) |>
  dplyr::select(-run_key)

assertthat::assert_that(
  base::all(base::file.exists(data_files |> dplyr::pull(path_source))),
  msg = "A listed file is missing from the research folder."
)

assertthat::assert_that(
  !base::anyDuplicated(data_files |> dplyr::pull(path_out)),
  msg = "Two files would be exported under the same name."
)


#----------------------------------------------------------#
# 2. Copy the files -----
#----------------------------------------------------------#

purrr::walk(
  .x = data_files |> dplyr::pull(question) |> base::unique(),
  .f = ~ base::dir.create(base::file.path(path_target, .x), recursive = TRUE)
)

# Files are read and written again, so that the dropped columns go
purrr::walk2(
  .x = data_files |> dplyr::pull(path_source),
  .y = data_files |> dplyr::pull(path_out),
  .f = ~ readr::read_csv(
    file = .x,
    col_types = readr::cols(.default = readr::col_character()),
    num_threads = 1L
  ) |>
    dplyr::select(-dplyr::any_of(vec_columns_dropped)) |>
    readr::write_csv(file = .y, na = "NA")
)

# Combined tables of repeated runs
data_combined <-
  tibble::tribble(
    ~question, ~name_out, ~script, ~source, ~pattern_dir, ~file_name,
    "q4_schema", "vaultkeepr_on_prototypes__workload_summary.csv",
    "12_profile_vaultkeepr_queries.R",
    "Vaultkeepr/prototype_<prototype run>_<variant>",
    stringr::str_c(
      "^prototype_",
      base::basename(purrr::chuck(list_runs, "prototypes"))
    ),
    "workload_summary",
    "q6_bulk_load", "chunk_size__steps.csv",
    "20_run_full_size_links.R (positions)",
    "Full_links/run_<time>_positions_chunk<n>",
    "_positions_chunk[0-9]+$",
    "steps",
    "q6_bulk_load", "chunk_size__chunk_check.csv",
    "20_run_full_size_links.R (positions)",
    "Full_links/run_<time>_positions_chunk<n>",
    "_positions_chunk[0-9]+$",
    "chunk_check",
    "q6_bulk_load", "chunk_size__run_info.csv",
    "20_run_full_size_links.R (positions)",
    "Full_links/run_<time>_positions_chunk<n>",
    "_positions_chunk[0-9]+$",
    "run_info"
  ) |>
  dplyr::mutate(
    data = purrr::pmap(
      .l = list(pattern_dir, file_name),
      .f = ~ {
        # Named, because the inner functions below cannot see `..2`
        pattern_dir_now <- ..1

        pattern_file_now <-
          stringr::str_c("^", ..2, "[.]csv$")

        vec_dirs_all <-
          base::list.dirs(path_research, recursive = TRUE)

        vec_dirs <-
          vec_dirs_all[
            stringr::str_detect(base::basename(vec_dirs_all), pattern_dir_now)
          ]

        vec_csv <-
          vec_dirs |>
          purrr::map(
            .f = ~ base::list.files(
              .x,
              pattern = pattern_file_now,
              recursive = TRUE,
              full.names = TRUE
            )
          ) |>
          base::unlist()

        assertthat::assert_that(
          base::length(vec_csv) > 0L,
          msg = "A combined table has no source files."
        )

        vec_csv |>
          purrr::map(
            .f = ~ readr::read_csv(
              file = .x,
              col_types = readr::cols(.default = readr::col_character()),
              num_threads = 1L
            ) |>
              dplyr::mutate(
                source_run = base::dirname(.x) |>
                  base::basename(),
                source_folder = base::dirname(.x) |>
                  base::dirname() |>
                  base::basename(),
                .before = 1L
              )
          ) |>
          dplyr::bind_rows() |>
          dplyr::select(-dplyr::any_of(vec_columns_dropped))
      }
    )
  )

purrr::walk(
  .x = data_combined |> dplyr::pull(question) |> base::unique(),
  .f = ~ base::dir.create(
    base::file.path(path_target, .x),
    recursive = TRUE,
    showWarnings = FALSE
  )
)

purrr::pwalk(
  .l = list(
    data_combined |> dplyr::pull(data),
    data_combined |> dplyr::pull(question),
    data_combined |> dplyr::pull(name_out)
  ),
  .f = ~ readr::write_csv(
    x = ..1,
    file = base::file.path(path_target, ..2, ..3),
    na = "NA"
  )
)


#----------------------------------------------------------#
# 3. Scan for paths; README -----
#----------------------------------------------------------#

vec_exported <-
  base::list.files(path_target, pattern = "[.]csv$", recursive = TRUE,
    full.names = TRUE
  )

vec_with_paths <-
  vec_exported |>
  purrr::keep(
    .p = ~ readr::read_lines(.x) |>
      stringr::str_detect(pattern_path) |>
      base::any()
  )

if (
  base::length(vec_with_paths) > 0L
) {
  cli::cli_abort(
    c(
      "Exported files hold path-like text; nothing may be committed.",
      "x" = "{base::basename(vec_with_paths)}"
    )
  )
}

data_readme_rows <-
  dplyr::bind_rows(
    data_files |>
      dplyr::select(question, name_out, script, source),
    data_combined |>
      dplyr::select(question, name_out, script, source)
  ) |>
  dplyr::arrange(question, name_out) |>
  dplyr::mutate(
    line = stringr::str_c(
      "| `", question, "/", name_out, "` | `", script, "` | `",
      source, "` |"
    )
  )

readr::write_lines(
  x = c(
    "# Tables behind the database design note",
    "",
    stringr::str_c(
      "These are the summary tables that the numbers of ",
      "`Database_design_2.0.0.md` come from, exported by ",
      "`R/Analyses/90_Database_research/22_export_note_tables.R` from the ",
      "git-ignored research folder `Data/Temp/Database_research/`. They ",
      "hold counts, sizes, timings and distributions only. Each row below ",
      "names the script that wrote the file and the run folder it came ",
      "from, relative to the research folder."
    ),
    "",
    "| File | Script | Run folder |",
    "| --- | --- | --- |",
    data_readme_rows |> dplyr::pull(line)
  ),
  file = base::file.path(path_target, "README.md")
)

cli::cli_inform(
  c(
    "v" = "Exported {length(vec_exported)} tables.",
    "i" = "Results in {.path {path_target}}."
  )
)
