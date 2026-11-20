#----------------------------------------------------------#
#
#
#                       VegVault
#
#         Profile the queries vaultkeepr sends to the database
#            - read-only, one child process per workload run
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Collect, time, and explain the SQL that the released vaultkeepr sends to
#   the database:
#   1. Export vaultkeepr at the configured ref from the local checkout with
#      `git archive` (the checkout itself is not touched).
#   2. Run every workload of 12a_run_vaultkeepr_workload.R (the vaultkeepr
#      vignette pipelines) `n_repetitions` times, each run in its own R
#      process with a timeout. Each run logs every statement and the time
#      until its result is released.
#   3. Run `EXPLAIN QUERY PLAN` on every distinct statement of the first
#      repetition, and list which indexes the plans use and which tables
#      they scan.
# The database is opened read-only. For the target `v1`, the file size,
#   modification time, and header are compared before and after, and no
#   journal, WAL, or SHM file may appear next to it. Long `IN` lists of
#   literal ids are shortened to their length in the saved statements. Each
#   run writes a new folder `run_<timestamp>`; the path of the database is
#   never printed.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/12_profile_vaultkeepr_queries.R
#     <target>
#   where <target> is `subset` (a dry run on the regional subset), `v1`, or
#   `prototype:<run folder>/<variant>` (a schema prototype written by
#   13_build_schema_prototypes.R, for example
#   `prototype:run_20261120_101500/tuple_links`). The subset and the
#   prototypes use the subset box for every workload.
#   Giving the name of an existing run folder as a second argument skips
#   the export and the workload runs and only summarises and explains the
#   logs of that run again.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration (resolves `path_to_vegvault` from the secrets file)
source(
  here::here("R/00_Config_file.R")
)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

pattern_prototype <-
  "^prototype:(run_[0-9_]+)/([a-z0-9_]+)$"

assertthat::assert_that(
  base::length(vec_args) %in% c(1L, 2L),
  purrr::chuck(vec_args, 1L) %in% c("v1", "subset") ||
    stringr::str_detect(purrr::chuck(vec_args, 1L), pattern_prototype),
  msg = stringr::str_c(
    "Give the target (`v1`, `subset` or `prototype:<run>/<variant>`) ",
    "and optionally a run folder."
  )
)

flag_reprocess <-
  base::length(vec_args) == 2L

name_target <-
  purrr::chuck(vec_args, 1L)

# Folder name of the target's results
name_target_folder <-
  stringr::str_replace_all(name_target, "[:/]", "_")

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_vaultkeepr <-
  purrr::chuck(list_settings, "vaultkeepr")

path_db <-
  if (
    name_target == "v1"
  ) {
    path_to_vegvault
  } else if (
    name_target == "subset"
  ) {
    here::here(
      "Data", "Temp", "Database_research", "Subset",
      stringr::str_c(
        "v1_subset_",
        purrr::chuck(list_settings, "subset", "box_name"),
        ".sqlite"
      )
    )
  } else {
    here::here(
      "Data", "Temp", "Database_research", "Prototypes",
      stringr::str_extract(name_target, pattern_prototype, group = 1L),
      stringr::str_c(
        stringr::str_extract(name_target, pattern_prototype, group = 2L),
        ".sqlite"
      )
    )
  }

# Every spelling of the database path, removed from any message shown
vec_path_spellings <-
  c(
    path_db,
    base::normalizePath(path_db, winslash = "/", mustWork = FALSE),
    base::normalizePath(path_db, winslash = "\\", mustWork = FALSE)
  ) |>
  base::unique()

time_run_start <-
  base::Sys.time()

path_run <-
  here::here(
    "Data", "Temp", "Database_research", "Vaultkeepr", name_target_folder,
    if (
      base::isTRUE(flag_reprocess)
    ) {
      purrr::chuck(vec_args, 2L)
    } else {
      stringr::str_c(
        "run_", base::format(time_run_start, "%Y%m%d_%H%M%S")
      )
    }
  )

path_logs <-
  base::file.path(path_run, "logs")

path_child_script <-
  here::here(
    "R/Analyses/90_Database_research/12a_run_vaultkeepr_workload.R"
  )

path_rscript <-
  base::file.path(base::R.home("bin"), "Rscript")

vec_workloads <-
  c(
    "explore_vault",
    "a01_taxa_distribution",
    "a01_taxon_names",
    "a02_vegetation_climate",
    "a02_abiotic_mean",
    "a03_traits_boxed",
    "a03_traits_vignette",
    "a04_extract_raw",
    "a05_references",
    "a06_age_uncertainty",
    "a07_classification_table"
  )

vec_sibling_suffix <-
  c("-journal", "-wal", "-shm")

assertthat::assert_that(
  base::file.exists(path_db),
  msg = "The database of the target does not exist."
)

assertthat::assert_that(
  base::dir.exists(path_run) == flag_reprocess,
  msg = "The run folder must be new, or exist when it is given."
)

base::dir.create(path = path_logs, recursive = TRUE, showWarnings = FALSE)


#----------------------------------------------------------#
# 1. Export vaultkeepr -----
#----------------------------------------------------------#

path_vaultkeepr_src <-
  base::file.path(path_run, "vaultkeepr_src")

path_vaultkeepr_info <-
  base::file.path(path_run, "vaultkeepr_info.csv")

if (
  base::isFALSE(flag_reprocess)
) {
  path_vaultkeepr_repo <-
    here::here(purrr::chuck(list_settings_vaultkeepr, "repo"))

  name_vaultkeepr_ref <-
    purrr::chuck(list_settings_vaultkeepr, "ref")

  sha_vaultkeepr <-
    processx::run(
      command = "git",
      args = c("-C", path_vaultkeepr_repo, "rev-parse", name_vaultkeepr_ref)
    ) |>
    purrr::chuck("stdout") |>
    stringr::str_squish()

  path_vaultkeepr_tar <-
    base::file.path(path_run, "vaultkeepr.tar")

  processx::run(
    command = "git",
    args = c(
      "-C", path_vaultkeepr_repo,
      "archive", "--format=tar",
      stringr::str_c("--output=", path_vaultkeepr_tar),
      sha_vaultkeepr
    )
  )

  utils::untar(tarfile = path_vaultkeepr_tar, exdir = path_vaultkeepr_src)

  version_vaultkeepr <-
    base::read.dcf(
      file = base::file.path(path_vaultkeepr_src, "DESCRIPTION"),
      fields = "Version"
    ) |>
    base::as.character()

  readr::write_csv(
    x = tibble::tibble(
      vaultkeepr_ref = name_vaultkeepr_ref,
      vaultkeepr_sha = sha_vaultkeepr,
      vaultkeepr_version = version_vaultkeepr
    ),
    file = path_vaultkeepr_info
  )
}

data_vaultkeepr_info <-
  readr::read_csv(file = path_vaultkeepr_info, show_col_types = FALSE)


#----------------------------------------------------------#
# 2. Record the file state before reading -----
#----------------------------------------------------------#

vec_header_raw_before <-
  base::readBin(con = path_db, what = "raw", n = 100L)

size_bytes_before <-
  base::file.size(path_db)

mtime_before <-
  base::file.mtime(path_db)

# A WAL-mode reader may create a `-shm` file next to the database, so the
#   file is only read when it uses a rollback journal
if (
  base::as.integer(vec_header_raw_before[19L]) != 1L ||
    base::as.integer(vec_header_raw_before[20L]) != 1L ||
    base::any(
      base::file.exists(stringr::str_c(path_db, vec_sibling_suffix))
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
# 3. Run the workloads -----
#----------------------------------------------------------#

# Repetitions are the outer loop, so the runs of a workload are spread
#   over the session
data_runs <-
  tidyr::expand_grid(
    repetition = base::seq_len(
      purrr::chuck(list_settings_vaultkeepr, "n_repetitions")
    ),
    workload = vec_workloads
  ) |>
  dplyr::mutate(
    path_log = base::file.path(
      path_logs,
      stringr::str_c(workload, "_", repetition, ".jsonl")
    )
  )

path_run_status <-
  base::file.path(path_run, "run_status.csv")

if (
  base::isFALSE(flag_reprocess)
) {
  data_run_status_new <-
    data_runs |>
    dplyr::mutate(
      result = purrr::pmap(
        .l = list(workload, repetition, path_log),
        .f = ~ {
          # cli templates cannot start with a dot, so the arguments get names
          name_workload_now <- ..1

          n_repetition_now <- ..2

          cli::cli_inform("Running {name_workload_now}, {n_repetition_now}.")

          time_child_start <-
            base::Sys.time()

          res_child <-
            processx::run(
              command = path_rscript,
              args = c(
                path_child_script,
                name_target,
                ..1,
                base::as.character(..2),
                path_vaultkeepr_src,
                ..3
              ),
              wd = here::here(),
              timeout = purrr::chuck(
                list_settings_vaultkeepr, "seconds_timeout"
              ),
              error_on_status = FALSE
            )

          tibble::tibble(
            exit_status = purrr::chuck(res_child, "status"),
            timed_out = purrr::chuck(res_child, "timeout"),
            seconds_child = base::difftime(
              base::Sys.time(),
              time_child_start,
              units = "secs"
            ) |>
              base::as.numeric(),
            # The end of the error output, without the database path
            stderr_tail = purrr::reduce(
              .x = vec_path_spellings,
              .f = ~ stringr::str_replace_all(
                string = .x,
                pattern = stringr::fixed(.y),
                replacement = "<database>"
              ),
              .init = purrr::chuck(res_child, "stderr")
            ) |>
              stringr::str_sub(start = -600L)
          )
        }
      )
    ) |>
    tidyr::unnest(cols = result)

  readr::write_csv(
    x = data_run_status_new |>
      dplyr::select(-path_log),
    file = path_run_status
  )
}

data_run_status <-
  readr::read_csv(file = path_run_status, show_col_types = FALSE)


#----------------------------------------------------------#
# 5. Statements and their times -----
#----------------------------------------------------------#

data_events <-
  data_runs |>
  dplyr::filter(base::file.exists(path_log)) |>
  dplyr::mutate(
    events = purrr::map(
      .x = path_log,
      .f = ~ base::readLines(.x, warn = FALSE) |>
        purrr::map(.f = jsonlite::fromJSON) |>
        purrr::map(
          .f = ~ purrr::discard(.x, .p = base::is.null) |>
            tibble::as_tibble()
        ) |>
        dplyr::bind_rows() |>
        # The run is identified by the outer columns
        dplyr::select(
          -dplyr::any_of(c("target", "workload", "repetition"))
        ) |>
        dplyr::mutate(event_order = dplyr::row_number())
    )
  ) |>
  dplyr::select(workload, repetition, events) |>
  tidyr::unnest(cols = events)

data_workload_summary <-
  data_events |>
  dplyr::filter(event == "summary") |>
  # Null fields are left out of the log, so a column may be missing
  dplyr::select(
    workload, repetition,
    dplyr::any_of(
      c(
        "box_name", "seconds", "n_rows", "result_mb", "max_memory_mb",
        "error"
      )
    )
  )

# Lists of five or more literal values (the ids vaultkeepr inlines) are
#   replaced by their length. The pattern is a single greedy character
#   class: ICU runs it without a backtrack stack, whereas repeated groups
#   and possessive loops overflow on lists of millions of ids. Lists of
#   fewer than five values are matched too and left unchanged.
pattern_value_list <-
  "\\(\\s*-?[0-9][-0-9.eE+,\\s]*\\)"

n_min_list_commas <- 4L

# A statement starts at `create` and ends at the next `release`
data_statements <-
  data_events |>
  dplyr::filter(event %in% c("create", "release")) |>
  dplyr::mutate(
    statement_order = base::cumsum(event == "create"),
    .by = c(workload, repetition)
  ) |>
  dplyr::summarise(
    fn_step = dplyr::first(fn_step),
    fn_inner = dplyr::first(fn_inner),
    sql = dplyr::first(sql),
    seconds = base::as.numeric(dplyr::last(epoch)) -
      base::as.numeric(dplyr::first(epoch)),
    flag_released = dplyr::last(event) == "release",
    .by = c(workload, repetition, statement_order)
  ) |>
  dplyr::mutate(
    n_listed_values = stringr::str_extract_all(sql, pattern_value_list) |>
      purrr::map(.f = ~ stringr::str_count(.x, ",")) |>
      purrr::map_int(
        .f = ~ base::sum(.x[.x >= n_min_list_commas] + 1L)
      ),
    sql_short = stringr::str_replace_all(
      string = sql,
      pattern = pattern_value_list,
      replacement = purrr::as_mapper(
        ~ dplyr::if_else(
          condition = stringr::str_count(.x, ",") >= n_min_list_commas,
          true = stringr::str_c(
            "(<", stringr::str_count(.x, ",") + 1L, " values>)"
          ),
          false = .x
        )
      )
    ) |>
      stringr::str_squish(),
    # Column probes of dbplyr (`WHERE (0 = 1)`) and table listings
    flag_probe = stringr::str_detect(sql, "WHERE \\(0 = 1\\)") |
      stringr::str_detect(sql, "sqlite_master|sqlite_temp_master")
  )


#----------------------------------------------------------#
# 6. Query plans -----
#----------------------------------------------------------#

data_statements_explain <-
  data_statements |>
  dplyr::filter(repetition == 1L, !flag_probe, flag_released) |>
  dplyr::distinct(workload, statement_order, sql, sql_short)

con_explain <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_db,
    flags = RSQLite::SQLITE_RO
  )

tryCatch(
  expr = {
    data_index_names <-
      DBI::dbGetQuery(
        conn = con_explain,
        statement = stringr::str_c(
          "SELECT name AS index_name, tbl_name AS table_name ",
          "FROM sqlite_master WHERE type = 'index' AND sql IS NOT NULL"
        )
      ) |>
      tibble::as_tibble()

    data_plans <-
      data_statements_explain |>
      dplyr::mutate(
        plan = purrr::map(
          .x = sql,
          .f = purrr::possibly(
            .f = ~ DBI::dbGetQuery(
              conn = con_explain,
              statement = stringr::str_c("EXPLAIN QUERY PLAN ", .x)
            ) |>
              tibble::as_tibble() |>
              dplyr::select(plan_id = id, plan_parent = parent, detail),
            otherwise = tibble::tibble(detail = "EXPLAIN failed")
          )
        )
      ) |>
      dplyr::select(workload, statement_order, sql_short, plan) |>
      tidyr::unnest(cols = plan)
  },
  finally = DBI::dbDisconnect(con_explain)
)

data_plan_access <-
  data_plans |>
  dplyr::mutate(
    index_name = stringr::str_match(
      detail, "USING (?:COVERING )?INDEX (\\w+)"
    )[, 2L],
    table_scanned = dplyr::if_else(
      condition = stringr::str_detect(detail, "^SCAN ") &
        !stringr::str_detect(detail, "USING"),
      true = stringr::str_match(detail, "^SCAN (\\w+)")[, 2L],
      false = NA_character_
    )
  )

table_index_usage <-
  data_index_names |>
  dplyr::left_join(
    data_plan_access |>
      tidyr::drop_na(index_name) |>
      dplyr::summarise(
        n_plan_steps = dplyr::n(),
        workloads = stringr::str_c(
          base::sort(base::unique(workload)),
          collapse = " "
        ),
        .by = index_name
      ),
    by = dplyr::join_by(index_name),
    relationship = "one-to-one"
  ) |>
  dplyr::mutate(
    n_plan_steps = tidyr::replace_na(n_plan_steps, 0L),
    flag_used = n_plan_steps > 0L
  ) |>
  dplyr::arrange(table_name, index_name)

table_scans <-
  data_plan_access |>
  tidyr::drop_na(table_scanned) |>
  dplyr::count(workload, table_scanned, name = "n_plan_steps")


#----------------------------------------------------------#
# 6b. Record the file state after reading -----
#----------------------------------------------------------#

flag_file_unchanged <-
  base::isTRUE(
    base::file.size(path_db) == size_bytes_before &&
      base::file.mtime(path_db) == mtime_before &&
      base::identical(
        vec_header_raw_before,
        base::readBin(con = path_db, what = "raw", n = 100L)
      ) &&
      !base::any(
        base::file.exists(stringr::str_c(path_db, vec_sibling_suffix))
      )
  )


#----------------------------------------------------------#
# 7. Save results -----
#----------------------------------------------------------#

data_run_info <-
  tibble::tibble(
    script = "12_profile_vaultkeepr_queries.R",
    target = name_target,
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    vaultkeepr_ref = data_vaultkeepr_info |> dplyr::pull(vaultkeepr_ref),
    vaultkeepr_sha = data_vaultkeepr_info |> dplyr::pull(vaultkeepr_sha),
    vaultkeepr_version = data_vaultkeepr_info |>
      dplyr::pull(vaultkeepr_version),
    reprocessed = flag_reprocess,
    n_repetitions = purrr::chuck(list_settings_vaultkeepr, "n_repetitions"),
    connection_flags = "SQLITE_RO",
    file_unchanged = flag_file_unchanged,
    r_version = base::as.character(base::getRversion()),
    rsqlite_version = base::as.character(utils::packageVersion("RSQLite")),
    dbplyr_version = base::as.character(utils::packageVersion("dbplyr"))
  )

list_outputs <-
  list(
    run_info = data_run_info,
    # vaultkeepr stops quietly on a failed check, so the last step that
    #   sent a statement shows where a run stopped
    workload_summary = data_workload_summary |>
      dplyr::left_join(
        data_statements |>
          dplyr::slice_max(
            order_by = statement_order,
            n = 1L,
            by = c(workload, repetition)
          ) |>
          dplyr::select(workload, repetition, last_step = fn_step),
        by = dplyr::join_by(workload, repetition),
        relationship = "one-to-one"
      ),
    statements = data_statements |>
      dplyr::select(-sql),
    plans = data_plans,
    index_usage = table_index_usage,
    table_scans = table_scans
  )

purrr::iwalk(
  .x = list_outputs,
  .f = ~ readr::write_csv(
    x = .x,
    file = base::file.path(path_run, stringr::str_c(.y, ".csv"))
  )
)

if (
  base::isFALSE(flag_file_unchanged)
) {
  cli::cli_abort("The database file differs after the read-only session.")
}

cli::cli_inform(
  c(
    "v" = "Profiled the vaultkeepr queries on {name_target}; file unchanged.",
    "i" = "Results saved to {.path {path_run}}."
  )
)
