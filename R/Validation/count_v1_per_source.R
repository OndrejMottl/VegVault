#----------------------------------------------------------#
#
#
#                       VegVault
#
#       Count the v1.0.0 taxon links and trait values per source
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Count, in the released v1.0.0 database, the rows of SampleTaxa and of
#   TraitsValue per dataset type and source type. The full scans of the
#   2.0.0 database research (R/Analyses/90_Database_research/
#   06_scan_v1_full.R) saved only their totals. The result is committed as
#   Data/Validation/v1.0.0_scan_per_source.csv, from which
#   R/Validation/build_v1_reference_counts.R builds the reference table of
#   the validation stage, so the stage never opens v1.0.0 (VegVault issue
#   96, decided by Ondrej Mottl on 2026-11-21).
# A one-off read of about 1 GB of the 110 GB file (two tables and their
#   indexes). It runs only with the maintainer's approval and never
#   alongside the full build, global raster processing or VACUUM.
# v1.0.0 is opened read-only (SQLITE_RO). Its size, modification time and
#   header are compared before and after, and it is not opened when it is
#   in WAL mode or has a journal file next to it. Its path comes from
#   secrets.yaml and is never printed; error messages have it removed.
# Each count is saved as soon as it is computed; a rerun skips the counts
#   already in the output file.
# Run from the repository root:
#   Rscript R/Validation/count_v1_per_source.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

path_output <-
  here::here("Data", "Validation", "v1.0.0_scan_per_source.csv")

path_v1 <-
  resolve_database_path(key = "database_v1_path")

if (
  !base::file.exists(path_v1)
) {
  cli::cli_abort(
    "The v1.0.0 database named by {.field database_v1_path} in
    {.file secrets.yaml} does not exist."
  )
}

# The two counts: rows per dataset type and source type; a row without a
#   dataset is counted under missing ids
data_queries <-
  tibble::tribble(
    ~metric, ~statement,
    "sample_taxa_rows",
    base::paste(
      "SELECT d.dataset_type_id, d.data_source_type_id, COUNT(*) AS n_rows",
      "FROM SampleTaxa AS st",
      "LEFT JOIN DatasetSample AS ds ON ds.sample_id = st.sample_id",
      "LEFT JOIN Datasets AS d ON d.dataset_id = ds.dataset_id",
      "GROUP BY 1, 2"
    ),
    "traits_value_rows",
    base::paste(
      "SELECT d.dataset_type_id, d.data_source_type_id, COUNT(*) AS n_rows",
      "FROM TraitsValue AS tv",
      "LEFT JOIN Datasets AS d ON d.dataset_id = tv.dataset_id",
      "GROUP BY 1, 2"
    )
  )


#----------------------------------------------------------#
# 1. Record the file state before reading -----
#----------------------------------------------------------#

vec_header_before <-
  base::readBin(con = path_v1, what = "raw", n = 100L)

size_before <-
  base::file.size(path_v1)

mtime_before <-
  base::file.mtime(path_v1)

# A WAL-mode reader may create a `-shm` file next to the database, so the
#   file is only opened when it uses a rollback journal
if (
  base::as.integer(vec_header_before[19L]) != 1L ||
    base::as.integer(vec_header_before[20L]) != 1L ||
    base::any(
      base::file.exists(stringr::str_c(path_v1, c("-journal", "-wal", "-shm")))
    )
) {
  cli::cli_abort(
    c(
      "The v1.0.0 database is in WAL mode or has a journal file next to it.",
      "i" = "It was not opened, to avoid creating files next to it."
    )
  )
}


#----------------------------------------------------------#
# 2. Count, saving each result -----
#----------------------------------------------------------#

data_done <-
  if (
    base::file.exists(path_output)
  ) {
    readr::read_csv(path_output, show_col_types = FALSE)
  } else {
    tibble::tibble(
      metric = base::character(0),
      dataset_type_id = base::integer(0),
      data_source_type_id = base::integer(0),
      n_rows = base::numeric(0),
      seconds = base::numeric(0)
    )
  }

vec_todo <-
  base::setdiff(
    dplyr::pull(data_queries, metric),
    dplyr::pull(data_done, metric)
  )

for (sel_metric in vec_todo) {
  statement <-
    data_queries |>
    dplyr::filter(metric == sel_metric) |>
    dplyr::pull(statement)

  time_start <-
    base::Sys.time()

  data_counts <-
    base::tryCatch(
      run_with_database(
        path_database = path_v1,
        fn = DBI::dbGetQuery,
        statement = statement,
        flag_read_only = TRUE
      ),
      error = function(cnd) {
        cli::cli_abort(
          stringr::str_replace_all(
            base::conditionMessage(cnd),
            stringr::fixed(path_v1),
            "<v1.0.0 database>"
          )
        )
      }
    )

  seconds_query <-
    base::as.numeric(base::Sys.time() - time_start, units = "secs")

  data_done <-
    dplyr::bind_rows(
      data_done,
      tibble::as_tibble(data_counts) |>
        dplyr::mutate(
          metric = sel_metric,
          dataset_type_id = base::as.integer(dataset_type_id),
          data_source_type_id = base::as.integer(data_source_type_id),
          n_rows = base::as.numeric(n_rows),
          seconds = base::round(seconds_query, 1)
        ) |>
        dplyr::select(
          metric, dataset_type_id, data_source_type_id, n_rows, seconds
        )
    ) |>
    dplyr::arrange(metric, dataset_type_id, data_source_type_id)

  base::dir.create(
    base::dirname(path_output),
    recursive = TRUE,
    showWarnings = FALSE
  )

  readr::write_csv(data_done, path_output, na = "")

  cli::cli_alert_success(
    "{sel_metric}: {base::nrow(data_counts)} groups in
    {base::round(seconds_query, 1)} s."
  )
}


#----------------------------------------------------------#
# 3. Confirm the file is unchanged -----
#----------------------------------------------------------#

flag_unchanged <-
  base::identical(
    vec_header_before,
    base::readBin(con = path_v1, what = "raw", n = 100L)
  ) &&
  base::identical(size_before, base::file.size(path_v1)) &&
  base::identical(mtime_before, base::file.mtime(path_v1))

if (
  !flag_unchanged
) {
  cli::cli_abort("The v1.0.0 database changed while it was read.")
}

# The totals must equal the exact counts of the full scans
#   (Documentation/Database_design_2.0.0.md, "Rows")
data_totals <-
  data_done |>
  dplyr::group_by(metric) |>
  dplyr::summarise(n_rows = base::sum(n_rows), .groups = "drop") |>
  dplyr::mutate(
    n_expected = dplyr::case_when(
      metric == "sample_taxa_rows" ~ 3689420,
      metric == "traits_value_rows" ~ 11366223
    )
  )

base::print(data_totals)

cli::cli_alert_success(
  "v1.0.0 unchanged; counts in {.file {path_output}}."
)
