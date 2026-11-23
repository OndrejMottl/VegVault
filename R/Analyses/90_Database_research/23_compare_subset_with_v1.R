#----------------------------------------------------------#
#
#
#                       VegVault
#
#      Compare the regional build with the v1.0.0 subset
#             - read-only, on natural keys
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Compare the disposable database of the `subset` profile, the regional
#   build of stages 01 to 03, with the v1.0.0 subset of the same box that
#   04_extract_v1_subset.R extracted, as decided on VegVault issue 90:
#   1. For every kind of row of `comparison: units` in
#      research_settings.yml, read the rows of both files by natural keys
#      (load_comparison_rows()): coordinates, ages, names and values, not
#      ids and not the dataset and sample names that 2.0.0 changes on
#      purpose.
#   2. Count, per scope (dataset type and source, or variable), the rows of
#      each side, of both and of one side only, with a checksum of each side
#      (compute_comparison_summary()), and keep up to `n_rows_per_scope`
#      differing rows per scope and direction (only in v1.0.0, only in
#      2.0.0; compute_comparison_differences()).
#   3. Mark every scope as equal, explained or unexplained against
#      `comparison: expected_differences` (diagnose_comparison_summary()).
# Both files are opened read-only; their size and modification time are
#   compared before and after. Each run writes a new folder under
#   `Data/Temp/Database_research/Comparison` and overwrites nothing:
#   `summary.csv` (every kind of row and scope with its counts, status and
#   reason) and `differences_<unit>.csv` (the kept differing rows with their
#   counts on each side). The script stops with an error when a difference
#   is unexplained, after both are written. The path of the regional build
#   comes from the data root and is never printed.
#
# Usage, from the project root, in the subset profile:
#   R_CONFIG_ACTIVE=subset Rscript
#     R/Analyses/90_Database_research/23_compare_subset_with_v1.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

assertthat::assert_that(
  load_config_value(value = "profile") == "subset",
  msg = "Run this script in the subset profile (R_CONFIG_ACTIVE=subset)."
)

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_subset <-
  purrr::chuck(list_settings, "subset")

list_settings_comparison <-
  purrr::chuck(list_settings, "comparison")

list_subset <-
  load_config_value(value = "subset")

# The v1.0.0 subset and the regional build must cover the same box
vec_box_keys <-
  c(
    "box_name", "lon_min", "lon_max", "lat_min", "lat_max", "margin_lat",
    "margin_lon"
  )

vec_box_equal <-
  purrr::map_lgl(
    .x = vec_box_keys,
    .f = ~ base::identical(
      base::as.character(purrr::chuck(list_settings_subset, .x)),
      base::as.character(purrr::chuck(list_subset, .x))
    )
  )

assertthat::assert_that(
  base::all(vec_box_equal),
  msg = stringr::str_c(
    "The box of research_settings.yml differs from the subset profile in: ",
    stringr::str_c(vec_box_keys[!vec_box_equal], collapse = ", ")
  )
)

path_v1 <-
  here::here(
    "Data", "Temp", "Database_research", "Subset",
    stringr::str_c(
      "v1_subset_",
      purrr::chuck(list_settings_subset, "box_name"),
      ".sqlite"
    )
  )

# The disposable database of the subset profile, under the data root
path_v2 <-
  resolve_database_path()

assertthat::assert_that(
  base::file.exists(path_v1),
  msg = "The v1.0.0 subset is missing; run 04_extract_v1_subset.R first."
)

assertthat::assert_that(
  base::file.exists(path_v2),
  msg = stringr::str_c(
    "The regional build is missing; run the stages 01 to 03 in the ",
    "subset profile first."
  )
)

vec_units <-
  base::unlist(purrr::chuck(list_settings_comparison, "units"))

n_digits <-
  purrr::chuck(list_settings_comparison, "n_digits")

n_rows_per_scope <-
  purrr::chuck(list_settings_comparison, "n_rows_per_scope")

list_expected <-
  purrr::pluck(
    list_settings_comparison,
    "expected_differences",
    .default = base::list()
  )

data_files_before <-
  base::file.info(c(path_v1, path_v2))[, c("size", "mtime")]

dir_run <-
  here::here(
    "Data", "Temp", "Database_research", "Comparison",
    stringr::str_c("run_", base::format(base::Sys.time(), "%Y%m%d_%H%M%S"))
  )

base::dir.create(dir_run, recursive = TRUE)

cli::cli_inform(
  "Comparing {base::length(vec_units)} kinds of rows; results in
  {.file {base::basename(dir_run)}}."
)


#----------------------------------------------------------#
# 1. Compare each kind of row -----
#----------------------------------------------------------#

data_summary <-
  purrr::map(
    .x = vec_units,
    .f = ~ {
      time_start <- base::Sys.time()

      data_v1 <-
        load_comparison_rows(
          path_database = path_v1,
          sel_unit = .x,
          n_digits = n_digits
        )

      data_v2 <-
        load_comparison_rows(
          path_database = path_v2,
          sel_unit = .x,
          n_digits = n_digits
        )

      data_unit_summary <-
        compute_comparison_summary(
          data_v1 = data_v1,
          data_v2 = data_v2,
          sel_unit = .x
        )

      # Up to `n_rows_per_scope` rows of each direction, so that the rows
      #   of one side do not hide those of the other
      compute_comparison_differences(data_v1 = data_v1, data_v2 = data_v2) |>
        dplyr::mutate(
          direction = dplyr::if_else(n_v1 > n_v2, "only_v1", "only_v2")
        ) |>
        dplyr::slice_head(n = n_rows_per_scope, by = c(scope, direction)) |>
        readr::write_csv(
          file = base::file.path(
            dir_run,
            stringr::str_c("differences_", .x, ".csv")
          ),
          na = ""
        )

      cli::cli_inform(
        "{.val {(.x)}}: {base::nrow(data_v1)} v1.0.0 and
        {base::nrow(data_v2)} 2.0.0 rows in
        {base::round(base::difftime(base::Sys.time(), time_start,
        units = 'secs'))} s."
      )

      base::rm(data_v1, data_v2)

      base::invisible(base::gc(verbose = FALSE))

      data_unit_summary
    }
  ) |>
  purrr::list_rbind()


#----------------------------------------------------------#
# 2. Explain the differences -----
#----------------------------------------------------------#

data_diagnosed <-
  diagnose_comparison_summary(
    data_summary = data_summary,
    list_expected = list_expected
  )

readr::write_csv(
  x = data_diagnosed,
  file = base::file.path(dir_run, "summary.csv"),
  na = ""
)

data_files_after <-
  base::file.info(c(path_v1, path_v2))[, c("size", "mtime")]

assertthat::assert_that(
  base::identical(data_files_before, data_files_after),
  msg = "A compared file changed during the comparison."
)

print(
  dplyr::select(
    data_diagnosed,
    unit, scope, n_v1, n_v2, n_only_v1, n_only_v2, status
  ),
  n = Inf,
  width = 200
)

data_unexplained <-
  dplyr::filter(data_diagnosed, status == "unexplained")

if (
  base::nrow(data_unexplained) > 0L
) {
  cli::cli_abort(
    c(
      "{base::nrow(data_unexplained)} scope{?s} with an unexplained
      difference.",
      "i" = "See {.file summary.csv} and the {.file differences_*.csv}
      files of {.file {base::basename(dir_run)}}."
    )
  )
}

vec_status <-
  dplyr::pull(data_diagnosed, status)

cli::cli_inform(
  "Every difference is explained: {base::sum(vec_status == 'equal')}
  scope{?s} equal, {base::sum(vec_status == 'explained')} explained."
)
