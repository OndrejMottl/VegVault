#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Build schema prototypes from the regional subset
#            - disposable files; the subset is read-only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Build each schema variant of `prototypes: variants` in
#   research_settings.yml from the rows of the regional subset, and measure
#   build time, file and object sizes, and content:
#   1. Compose each variant: the v1 schema (Data/SQL/make_tables.sql)
#      without the named index sets, changed by the SQL files in
#      Prototype_schemas/ (see the rules in without_rowid.sql). Every
#      variant is first run against an empty in-memory copy of the v1
#      schema, so that a wrong statement fails before any timed build.
#   2. Build every variant `n_build_repetitions` times, interleaved, into
#      new files: tables, then rows (tables that a variant does not change
#      are copied in key order), then indexes, views and `ANALYZE`. Every
#      statement is timed. The settings of `prototypes: pragmas` apply to
#      every build. Statements that derive positions from the v1 links
#      are timed as `derive`, apart from the build.
#   3. Keep the files of the last repetition. On them, check that every
#      table or view of the subset holds the same rows (counts, and
#      `EXCEPT` both ways for views and rewritten tables) and run the
#      `@check` queries of the SQL files.
#   4. Measure the size of every table and index with `dbstat`, through
#      the sqlite3 command-line tool, opened read-only.
#   5. Type probes: the links of the `tuple_links` variant stored with
#      distances as integer km (v1), integer metres and real km, and the
#      sample ages as REAL and as INTEGER, each in its own table of a
#      separate file, to measure their size. The true distances are
#      recomputed with geosphere::distGeo(), as v1 did, and compared with
#      the stored integer km.
# The subset is attached read-only (`mode=ro`); its size, modification
#   time and header are compared before and after. v1.0.0 is not opened.
#   Each run writes a new folder `run_<timestamp>` under
#   `Data/Temp/Database_research/Prototypes` and never overwrites; a failed
#   run is restarted from the beginning in a new folder.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/13_build_schema_prototypes.R
#     [dry_run]
#   With `dry_run`, the script stops after step 1: it composes and dry-runs
#   the variants, compares the subset's tables and columns with the v1
#   schema, writes the composed schemas to `dryrun_<timestamp>`, and builds
#   nothing.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 0L ||
    base::identical(vec_args, "dry_run"),
  msg = "The only optional argument is `dry_run`."
)

flag_dry_run <-
  base::identical(vec_args, "dry_run")

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_prototypes <-
  purrr::chuck(list_settings, "prototypes")

n_build_repetitions <-
  purrr::chuck(list_settings_prototypes, "n_build_repetitions") |>
  base::as.integer()

path_research <-
  here::here("Data", "Temp", "Database_research")

path_subset <-
  base::file.path(
    path_research,
    "Subset",
    stringr::str_c(
      "v1_subset_",
      purrr::chuck(list_settings, "subset", "box_name"),
      ".sqlite"
    )
  ) |>
  base::normalizePath(winslash = "/", mustWork = TRUE)

# The subset is attached through a URI, so its path must not need encoding
assertthat::assert_that(
  !stringr::str_detect(path_subset, "[ ?#%]"),
  msg = "The subset path holds a character that a URI would have to encode."
)

uri_subset <-
  stringr::str_c("file:", path_subset, "?mode=ro")

path_schema_dir <-
  here::here("R/Analyses/90_Database_research/Prototype_schemas")

path_make_tables <-
  here::here("Data/SQL/make_tables.sql")

path_sqlite_exe <-
  base::file.path(
    path_research,
    "Tools",
    "sqlite-tools-3540100",
    "sqlite3.exe"
  )

assertthat::assert_that(
  base::file.exists(path_sqlite_exe),
  msg = "The sqlite3 command-line tool is missing from Data/Temp."
)

time_run_start <-
  base::Sys.time()

path_run <-
  base::file.path(
    path_research,
    "Prototypes",
    stringr::str_c(
      dplyr::if_else(flag_dry_run, "dryrun_", "run_"),
      base::format(time_run_start, "%Y%m%d_%H%M%S")
    )
  )

assertthat::assert_that(
  !base::dir.exists(path_run),
  msg = "The run folder exists already."
)

base::dir.create(
  path = base::file.path(path_run, "schemas"),
  recursive = TRUE
)

list_variants <-
  purrr::chuck(list_settings_prototypes, "variants")

vec_variant_names <-
  list_variants |>
  purrr::map_chr(.f = ~ purrr::chuck(.x, "name"))

list_index_sets <-
  purrr::chuck(list_settings_prototypes, "index_sets")

# PRAGMA statements of every build, run before anything is attached, so
#   that they apply to the new file only
vec_pragma_sql <-
  purrr::chuck(list_settings_prototypes, "pragmas") |>
  purrr::imap_chr(
    .f = ~ stringr::str_c("PRAGMA ", .y, " = ", .x)
  ) |>
  base::unname()

# Size of every table and index, with the table it belongs to
sql_dbstat <-
  stringr::str_c(
    "SELECT d.name AS object, coalesce(s.type, 'internal') AS type, ",
    "coalesce(s.tbl_name, d.name) AS table_name, d.pageno AS n_pages, ",
    "d.pgsize AS bytes, d.payload AS payload_bytes, ",
    "d.unused AS unused_bytes, d.ncell AS n_cells ",
    "FROM dbstat AS d LEFT JOIN sqlite_schema AS s ON s.name = d.name ",
    "WHERE d.aggregate = TRUE ORDER BY bytes DESC;"
  )


#----------------------------------------------------------#
# 1. Record the subset state before reading -----
#----------------------------------------------------------#

vec_subset_header_before <-
  base::readBin(con = path_subset, what = "raw", n = 100L)

size_subset_before <-
  base::file.size(path_subset)

mtime_subset_before <-
  base::file.mtime(path_subset)

# A WAL-mode reader may create a `-shm` file next to the database, so the
#   subset is only attached when it uses a rollback journal
if (
  base::as.integer(vec_subset_header_before[19L]) != 1L ||
    base::as.integer(vec_subset_header_before[20L]) != 1L
) {
  cli::cli_abort("The subset is in WAL mode; it was not attached.")
}


#----------------------------------------------------------#
# 2. Read the SQL files -----
#----------------------------------------------------------#

data_sql_files <-
  tibble::tibble(
    path = c(
      path_make_tables,
      base::list.files(
        path = path_schema_dir,
        pattern = "[.]sql$",
        full.names = TRUE
      )
    )
  ) |>
  dplyr::mutate(
    file_name = base::basename(path),
    lines = purrr::map(.x = path, .f = readr::read_lines)
  )

# Statements end with `;` at a line end; full-line comments are dropped
data_statements_all <-
  data_sql_files |>
  dplyr::mutate(
    sql = purrr::map(
      .x = lines,
      .f = ~ .x |>
        stringr::str_subset(pattern = "^\\s*--", negate = TRUE) |>
        stringr::str_c(collapse = "\n") |>
        stringr::str_split(pattern = ";\\s*(\\n|$)") |>
        purrr::chuck(1L) |>
        stringr::str_trim() |>
        purrr::keep(.p = base::nzchar)
    )
  ) |>
  dplyr::select(file_name, sql) |>
  tidyr::unnest(sql) |>
  dplyr::mutate(
    n_statement = dplyr::row_number(),
    .by = file_name
  ) |>
  dplyr::mutate(
    kind = dplyr::case_when(
      stringr::str_detect(sql, "^CREATE TEMP TABLE ") ~ "derive",
      stringr::str_detect(sql, "^CREATE TABLE ") ~ "table",
      stringr::str_detect(sql, "^CREATE (UNIQUE )?INDEX ") ~ "index",
      stringr::str_detect(sql, "^CREATE VIEW ") ~ "view",
      stringr::str_detect(sql, "^INSERT INTO ") ~ "load",
      .default = NA_character_
    ),
    object = stringr::str_extract(
      string = sql,
      pattern = stringr::str_c(
        "^(?:CREATE TEMP TABLE|CREATE TABLE|CREATE (?:UNIQUE )?INDEX|",
        "CREATE VIEW|INSERT INTO) \"?(\\w+)\"?"
      ),
      group = 1L
    ),
    index_table = dplyr::if_else(
      condition = kind == "index",
      true = stringr::str_extract(
        string = sql,
        pattern = " ON \"?(\\w+)\"?",
        group = 1L
      ),
      false = NA_character_
    )
  )

assertthat::assert_that(
  !base::anyNA(data_statements_all |> dplyr::pull(kind)),
  !base::anyNA(data_statements_all |> dplyr::pull(object)),
  msg = "A statement of the SQL files is not of a known kind."
)

data_directives_all <-
  data_sql_files |>
  dplyr::select(file_name, lines) |>
  tidyr::unnest(lines) |>
  dplyr::filter(stringr::str_detect(lines, "^-- @")) |>
  dplyr::mutate(
    directive = stringr::str_extract(lines, "^-- @(\\w+)", group = 1L),
    object = stringr::str_extract(lines, "^-- @\\w+ (\\w+)", group = 1L),
    check_sql = stringr::str_extract(
      string = lines,
      pattern = "^-- @check \\w+: (.+)$",
      group = 1L
    )
  )

assertthat::assert_that(
  base::all(
    data_directives_all |>
      dplyr::pull(directive) %in% c("omit", "drop_index", "check")
  ),
  !base::anyNA(data_directives_all |> dplyr::pull(object)),
  msg = "A directive of the SQL files is unknown or incomplete."
)


#----------------------------------------------------------#
# 3. Compose and dry-run each variant -----
#----------------------------------------------------------#

# The v1 tables, created in an empty in-memory schema `src`, stand in for
#   the subset in the dry run
vec_src_table_sql <-
  data_statements_all |>
  dplyr::filter(file_name == "make_tables.sql", kind == "table") |>
  dplyr::pull(sql) |>
  stringr::str_replace(
    pattern = "^CREATE TABLE ",
    replacement = "CREATE TABLE src."
  )

list_plans <-
  list_variants |>
  rlang::set_names(vec_variant_names) |>
  purrr::map(
    .f = ~ {
      vec_files_now <-
        purrr::chuck(.x, "sql_files") |>
        base::unlist() |>
        base::as.character()

      data_files_now <-
        tibble::tibble(
          file_name = c("make_tables.sql", vec_files_now),
          file_order = base::seq_along(file_name) - 1L
        )

      assertthat::assert_that(
        base::all(
          vec_files_now %in% (data_sql_files |> dplyr::pull(file_name))
        ),
        msg = "A variant names an SQL file that does not exist."
      )

      # A later file replaces an object of an earlier file in its place
      data_statements_now <-
        data_statements_all |>
        dplyr::inner_join(data_files_now, by = "file_name") |>
        dplyr::mutate(n_order = file_order * 10000L + n_statement) |>
        dplyr::mutate(
          n_position = base::min(n_order),
          .by = c(kind, object)
        ) |>
        dplyr::filter(
          file_order == base::max(file_order),
          .by = c(kind, object)
        ) |>
        dplyr::arrange(n_position, n_order)

      data_directives_now <-
        data_directives_all |>
        dplyr::inner_join(data_files_now, by = "file_name")

      vec_omit <-
        data_directives_now |>
        dplyr::filter(directive == "omit") |>
        dplyr::pull(object)

      vec_drop_index <-
        c(
          purrr::chuck(.x, "drop_index_sets") |>
            base::unlist() |>
            base::as.character() |>
            purrr::map(.f = ~ purrr::chuck(list_index_sets, .x)) |>
            base::unlist() |>
            base::as.character(),
          data_directives_now |>
            dplyr::filter(directive == "drop_index") |>
            dplyr::pull(object)
        )

      assertthat::assert_that(
        base::all(
          vec_drop_index %in% (
            data_statements_now |>
              dplyr::filter(kind == "index") |>
              dplyr::pull(object)
          )
        ),
        msg = "A dropped index does not exist in the variant."
      )

      data_tables_now <-
        data_statements_now |>
        dplyr::filter(kind == "table", !object %in% vec_omit)

      data_custom_now <-
        data_statements_now |>
        dplyr::filter(
          kind %in% c("derive", "load"),
          !object %in% vec_omit
        )

      data_indexes_now <-
        data_statements_now |>
        dplyr::filter(
          kind == "index",
          !object %in% vec_drop_index,
          !index_table %in% vec_omit
        )

      data_views_now <-
        data_statements_now |>
        dplyr::filter(kind == "view")

      assertthat::assert_that(
        base::length(
          base::intersect(
            data_tables_now |> dplyr::pull(object),
            data_views_now |> dplyr::pull(object)
          )
        ) == 0L,
        msg = "A view has the name of a table of the variant."
      )

      data_checks_now <-
        data_directives_now |>
        dplyr::filter(directive == "check") |>
        dplyr::slice_max(
          order_by = file_order,
          n = 1L,
          with_ties = FALSE,
          by = object
        ) |>
        dplyr::select(check = object, sql = check_sql)

      # Dry run: an empty v1 schema as `src`
      con_plan <-
        DBI::dbConnect(RSQLite::SQLite(), ":memory:")

      DBI::dbExecute(con_plan, "ATTACH DATABASE ':memory:' AS src")

      purrr::walk(
        .x = vec_src_table_sql,
        .f = ~ DBI::dbExecute(con_plan, .x)
      )

      purrr::walk(
        .x = data_tables_now |> dplyr::pull(sql),
        .f = ~ DBI::dbExecute(con_plan, .x)
      )

      vec_src_tables <-
        DBI::dbGetQuery(
          con_plan,
          stringr::str_c(
            "SELECT name FROM src.sqlite_schema ",
            "WHERE type = 'table' AND name NOT LIKE 'sqlite_%'"
          )
        ) |>
        dplyr::pull(name)

      vec_custom_loaded <-
        data_custom_now |>
        dplyr::filter(kind == "load") |>
        dplyr::pull(object) |>
        base::unique()

      # Tables a variant does not rewrite are copied in key order
      data_generic_now <-
        tibble::tibble(
          object = data_tables_now |>
            dplyr::pull(object) |>
            base::intersect(vec_src_tables) |>
            base::setdiff(vec_custom_loaded)
        ) |>
        dplyr::mutate(
          sql = purrr::map_chr(
            .x = object,
            .f = ~ {
              data_info_main <-
                DBI::dbGetQuery(
                  con_plan,
                  stringr::str_c("PRAGMA main.table_info(\"", .x, "\")")
                )

              vec_src_columns <-
                DBI::dbGetQuery(
                  con_plan,
                  stringr::str_c("PRAGMA src.table_info(\"", .x, "\")")
                ) |>
                dplyr::pull(name)

              vec_columns <-
                data_info_main |>
                dplyr::pull(name)

              assertthat::assert_that(
                base::all(vec_columns %in% vec_src_columns),
                msg = "A copied table has a column the subset lacks."
              )

              vec_order <-
                data_info_main |>
                dplyr::filter(pk > 0L) |>
                dplyr::arrange(pk) |>
                dplyr::pull(name)

              text_columns <-
                stringr::str_c("\"", vec_columns, "\"", collapse = ", ")

              text_order <-
                if (
                  base::length(vec_order) == 0L
                ) {
                  "rowid"
                } else {
                  stringr::str_c("\"", vec_order, "\"", collapse = ", ")
                }

              stringr::str_c(
                "INSERT INTO main.\"", .x, "\" (", text_columns, ") ",
                "SELECT ", text_columns, " FROM src.\"", .x, "\" ",
                "ORDER BY ", text_order
              )
            }
          )
        )

      data_plan_now <-
        dplyr::bind_rows(
          data_tables_now |>
            dplyr::mutate(phase = "table") |>
            dplyr::select(phase, kind, object, sql),
          data_generic_now |>
            dplyr::mutate(phase = "load", kind = "copy"),
          data_custom_now |>
            dplyr::mutate(
              phase = dplyr::if_else(kind == "derive", "derive", "load")
            ) |>
            dplyr::select(phase, kind, object, sql),
          data_indexes_now |>
            dplyr::mutate(phase = "index") |>
            dplyr::select(phase, kind, object, sql),
          data_views_now |>
            dplyr::mutate(phase = "view") |>
            dplyr::select(phase, kind, object, sql),
          tibble::tibble(
            phase = "analyze",
            kind = "analyze",
            object = "main",
            sql = "ANALYZE main"
          )
        ) |>
        dplyr::mutate(step_order = dplyr::row_number())

      # Run the rest of the plan on the empty schema (the tables exist
      #   already); any wrong statement fails here
      purrr::walk(
        .x = data_plan_now |>
          dplyr::filter(phase != "table") |>
          dplyr::pull(sql),
        .f = ~ DBI::dbExecute(con_plan, .x)
      )

      # Objects compared with the subset: the rows of every table or view
      #   of the same name; EXCEPT both ways for rewritten ones
      vec_main_objects <-
        DBI::dbGetQuery(
          con_plan,
          stringr::str_c(
            "SELECT name FROM main.sqlite_schema ",
            "WHERE type IN ('table', 'view') AND name NOT LIKE 'sqlite_%'"
          )
        ) |>
        dplyr::pull(name)

      data_content_now <-
        tibble::tibble(
          object = base::intersect(vec_src_tables, vec_main_objects)
        ) |>
        dplyr::mutate(
          flag_rewritten = object %in% c(
            vec_custom_loaded,
            data_views_now |> dplyr::pull(object)
          ),
          text_columns = purrr::map_chr(
            .x = object,
            .f = ~ stringr::str_c(
              "\"",
              base::intersect(
                DBI::dbGetQuery(
                  con_plan,
                  stringr::str_c("PRAGMA main.table_info(\"", .x, "\")")
                ) |>
                  dplyr::pull(name),
                DBI::dbGetQuery(
                  con_plan,
                  stringr::str_c("PRAGMA src.table_info(\"", .x, "\")")
                ) |>
                  dplyr::pull(name)
              ),
              "\"",
              collapse = ", "
            )
          ),
          sql_count = stringr::str_c(
            "SELECT (SELECT count(*) FROM main.\"", object, "\") AS n_main, ",
            "(SELECT count(*) FROM src.\"", object, "\") AS n_src"
          ),
          sql_only_main = stringr::str_c(
            "SELECT count(*) AS n FROM (SELECT ", text_columns,
            " FROM main.\"", object, "\" EXCEPT SELECT ", text_columns,
            " FROM src.\"", object, "\")"
          ),
          sql_only_src = stringr::str_c(
            "SELECT count(*) AS n FROM (SELECT ", text_columns,
            " FROM src.\"", object, "\" EXCEPT SELECT ", text_columns,
            " FROM main.\"", object, "\")"
          )
        )

      purrr::walk(
        .x = c(
          data_content_now |> dplyr::pull(sql_count),
          data_content_now |> dplyr::pull(sql_only_main),
          data_content_now |> dplyr::pull(sql_only_src),
          data_checks_now |> dplyr::pull(sql)
        ),
        .f = ~ DBI::dbGetQuery(con_plan, .x)
      )

      DBI::dbDisconnect(con_plan)

      list(
        plan = data_plan_now,
        checks = data_checks_now,
        content = data_content_now
      )
    }
  )

# The composed schema of each variant, as run
purrr::iwalk(
  .x = list_plans,
  .f = ~ readr::write_lines(
    x = purrr::chuck(.x, "plan") |>
      dplyr::pull(sql) |>
      stringr::str_c(";"),
    file = base::file.path(path_run, "schemas", stringr::str_c(.y, ".sql"))
  )
)

# The subset must have the v1 tables and columns the dry run assumed
con_subset_check <-
  DBI::dbConnect(RSQLite::SQLite(), ":memory:")

DBI::dbExecute(con_subset_check, "ATTACH DATABASE ':memory:' AS v1")

purrr::walk(
  .x = vec_src_table_sql |>
    stringr::str_replace(
      pattern = "^CREATE TABLE src[.]",
      replacement = "CREATE TABLE v1."
    ),
  .f = ~ DBI::dbExecute(con_subset_check, .x)
)

DBI::dbExecute(
  con_subset_check,
  "ATTACH DATABASE ? AS src",
  params = list(uri_subset)
)

text_columns_v1 <-
  DBI::dbGetQuery(
    con_subset_check,
    stringr::str_c(
      "SELECT m.name || '.' || p.name AS col FROM v1.sqlite_schema AS m ",
      "JOIN pragma_table_info(m.name, 'v1') AS p WHERE m.type = 'table' ",
      "ORDER BY 1"
    )
  ) |>
  dplyr::pull(col)

text_columns_subset <-
  DBI::dbGetQuery(
    con_subset_check,
    stringr::str_c(
      "SELECT m.name || '.' || p.name AS col FROM src.sqlite_schema AS m ",
      "JOIN pragma_table_info(m.name, 'src') AS p WHERE m.type = 'table' ",
      "AND m.name NOT LIKE 'sqlite_%' ORDER BY 1"
    )
  ) |>
  dplyr::pull(col)

DBI::dbDisconnect(con_subset_check)

assertthat::assert_that(
  base::identical(text_columns_v1, text_columns_subset),
  msg = "The subset tables differ from Data/SQL/make_tables.sql."
)

cli::cli_inform(
  "All {length(list_plans)} variants passed the dry run."
)

if (
  base::isTRUE(flag_dry_run)
) {
  cli::cli_inform("Dry run only; nothing was built.")

  base::quit(save = "no", status = 0L)
}


#----------------------------------------------------------#
# 4. Build the variants -----
#----------------------------------------------------------#

# Repetitions are the outer loop, so the builds of a variant are spread
#   over the session
data_builds <-
  tidyr::expand_grid(
    repetition = base::seq_len(n_build_repetitions),
    variant = vec_variant_names
  )

list_build_results <-
  purrr::pmap(
    .l = list(
      data_builds |> dplyr::pull(repetition),
      data_builds |> dplyr::pull(variant)
    ),
    .f = ~ {
      # cli templates cannot start with a dot, so the arguments get names
      n_repetition_now <- ..1

      name_variant_now <- ..2

      flag_keep <-
        n_repetition_now == n_build_repetitions

      path_file_now <-
        base::file.path(
          path_run,
          if (
            base::isTRUE(flag_keep)
          ) {
            stringr::str_c(name_variant_now, ".sqlite")
          } else {
            stringr::str_c(
              name_variant_now, "_rep", n_repetition_now, ".sqlite"
            )
          }
        )

      cli::cli_inform(
        "Building {name_variant_now}, repetition {n_repetition_now}."
      )

      con_build <-
        DBI::dbConnect(RSQLite::SQLite(), path_file_now)

      purrr::walk(
        .x = vec_pragma_sql,
        .f = ~ DBI::dbGetQuery(con_build, .x)
      )

      DBI::dbExecute(
        con_build,
        "ATTACH DATABASE ? AS src",
        params = list(uri_subset)
      )

      data_statements_now <-
        purrr::chuck(list_plans, name_variant_now, "plan") |>
        dplyr::mutate(
          result = purrr::pmap(
            .l = list(sql, kind, object),
            .f = ~ {
              time_statement_start <-
                base::Sys.time()

              n_rows_changed <-
                DBI::dbExecute(con_build, ..1)

              seconds_statement <-
                base::difftime(
                  base::Sys.time(),
                  time_statement_start,
                  units = "secs"
                ) |>
                base::as.numeric()

              n_rows_now <-
                if (
                  ..2 == "derive"
                ) {
                  DBI::dbGetQuery(
                    con_build,
                    stringr::str_c(
                      "SELECT count(*) AS n FROM temp.\"", ..3, "\""
                    )
                  ) |>
                    dplyr::pull(n)
                } else {
                  n_rows_changed
                }

              tibble::tibble(
                seconds = seconds_statement,
                n_rows = n_rows_now
              )
            }
          )
        ) |>
        tidyr::unnest(result) |>
        dplyr::select(-sql) |>
        dplyr::mutate(
          variant = name_variant_now,
          repetition = n_repetition_now,
          .before = 1L
        )

      data_file_now <-
        tibble::tibble(
          variant = name_variant_now,
          repetition = n_repetition_now,
          page_size = DBI::dbGetQuery(con_build, "PRAGMA main.page_size") |>
            purrr::chuck(1L),
          page_count = DBI::dbGetQuery(
            con_build, "PRAGMA main.page_count"
          ) |>
            purrr::chuck(1L),
          freelist_count = DBI::dbGetQuery(
            con_build, "PRAGMA main.freelist_count"
          ) |>
            purrr::chuck(1L)
        )

      # Checks of content and of the SQL files, on the kept files only
      data_schema_checks_now <-
        if (
          base::isTRUE(flag_keep)
        ) {
          purrr::chuck(list_plans, name_variant_now, "checks") |>
            dplyr::mutate(
              value = purrr::map_dbl(
                .x = sql,
                .f = ~ DBI::dbGetQuery(con_build, .x) |>
                  purrr::chuck(1L) |>
                  base::as.numeric()
              ),
              passed = value == 1,
              variant = name_variant_now,
              .before = 1L
            ) |>
            dplyr::select(-sql)
        } else {
          NULL
        }

      data_content_now <-
        if (
          base::isTRUE(flag_keep)
        ) {
          purrr::chuck(list_plans, name_variant_now, "content") |>
            dplyr::mutate(
              result = purrr::pmap(
                .l = list(
                  sql_count, sql_only_main, sql_only_src, flag_rewritten
                ),
                .f = ~ {
                  time_check_start <-
                    base::Sys.time()

                  data_counts <-
                    DBI::dbGetQuery(con_build, ..1)

                  n_only_main <-
                    if (
                      base::isTRUE(..4)
                    ) {
                      DBI::dbGetQuery(con_build, ..2) |>
                        dplyr::pull(n)
                    } else {
                      NA_real_
                    }

                  n_only_src <-
                    if (
                      base::isTRUE(..4)
                    ) {
                      DBI::dbGetQuery(con_build, ..3) |>
                        dplyr::pull(n)
                    } else {
                      NA_real_
                    }

                  tibble::tibble(
                    n_main = data_counts |> dplyr::pull(n_main),
                    n_src = data_counts |> dplyr::pull(n_src),
                    n_only_main = n_only_main,
                    n_only_src = n_only_src,
                    seconds = base::difftime(
                      base::Sys.time(),
                      time_check_start,
                      units = "secs"
                    ) |>
                      base::as.numeric()
                  )
                }
              )
            ) |>
            tidyr::unnest(result) |>
            dplyr::select(
              object, flag_rewritten, n_main, n_src, n_only_main,
              n_only_src, seconds
            ) |>
            dplyr::mutate(variant = name_variant_now, .before = 1L)
        } else {
          NULL
        }

      DBI::dbDisconnect(con_build)

      data_file_now <-
        data_file_now |>
        dplyr::mutate(file_bytes = base::file.size(path_file_now))

      if (
        base::isFALSE(flag_keep)
      ) {
        base::unlink(path_file_now)
      }

      list(
        statements = data_statements_now,
        file = data_file_now,
        schema_checks = data_schema_checks_now,
        content = data_content_now
      )
    }
  )

data_build_statements <-
  list_build_results |>
  purrr::map(.f = ~ purrr::chuck(.x, "statements")) |>
  dplyr::bind_rows()

data_build_files <-
  list_build_results |>
  purrr::map(.f = ~ purrr::chuck(.x, "file")) |>
  dplyr::bind_rows()

data_schema_checks <-
  list_build_results |>
  purrr::map(.f = ~ purrr::pluck(.x, "schema_checks")) |>
  dplyr::bind_rows()

data_content_checks <-
  list_build_results |>
  purrr::map(.f = ~ purrr::pluck(.x, "content")) |>
  dplyr::bind_rows()

readr::write_csv(
  x = data_build_statements,
  file = base::file.path(path_run, "build_statements.csv")
)

readr::write_csv(
  x = data_build_files,
  file = base::file.path(path_run, "build_files.csv")
)

readr::write_csv(
  x = data_schema_checks,
  file = base::file.path(path_run, "schema_checks.csv")
)

readr::write_csv(
  x = data_content_checks,
  file = base::file.path(path_run, "content_checks.csv")
)

# Build time by phase; `derive` is reported apart from the build
data_build_summary <-
  data_build_statements |>
  dplyr::summarise(
    seconds = base::sum(seconds),
    .by = c(variant, repetition, phase)
  ) |>
  tidyr::pivot_wider(
    names_from = phase,
    values_from = seconds,
    values_fill = 0,
    names_prefix = "seconds_"
  ) |>
  dplyr::mutate(
    seconds_build = seconds_table + seconds_load + seconds_index +
      seconds_view + seconds_analyze
  ) |>
  dplyr::left_join(data_build_files, by = c("variant", "repetition"))

readr::write_csv(
  x = data_build_summary,
  file = base::file.path(path_run, "build_summary.csv")
)


#----------------------------------------------------------#
# 5. Object sizes -----
#----------------------------------------------------------#

data_object_sizes <-
  vec_variant_names |>
  purrr::map(
    .f = ~ {
      res_dbstat <-
        processx::run(
          command = path_sqlite_exe,
          args = c(
            "-readonly",
            "-csv",
            "-header",
            base::file.path(path_run, stringr::str_c(.x, ".sqlite")),
            sql_dbstat
          ),
          timeout = 3600
        )

      readr::read_csv(
        file = base::I(purrr::chuck(res_dbstat, "stdout")),
        show_col_types = FALSE,
        num_threads = 1L
      ) |>
        dplyr::mutate(variant = .x, .before = 1L)
    }
  ) |>
  dplyr::bind_rows()

readr::write_csv(
  x = data_object_sizes,
  file = base::file.path(path_run, "object_sizes.csv")
)


#----------------------------------------------------------#
# 6. Type probes -----
#----------------------------------------------------------#

path_tuple_links <-
  base::file.path(path_run, "tuple_links.sqlite")

assertthat::assert_that(
  base::file.exists(path_tuple_links),
  msg = "The type probes need the `tuple_links` variant."
)

con_probe_read <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_tuple_links,
    flags = RSQLite::SQLITE_RO
  )

DBI::dbExecute(
  con_probe_read,
  "ATTACH DATABASE ? AS src",
  params = list(uri_subset)
)

data_probe_links <-
  DBI::dbGetQuery(
    con_probe_read,
    stringr::str_c(
      "SELECT pl.position_id, pl.sample_ref_id, pl.distance_in_km, ",
      "pl.distance_in_years, p.coord_long, p.coord_lat, ",
      "d.coord_long AS grid_long, d.coord_lat AS grid_lat ",
      "FROM main.PositionLink AS pl ",
      "JOIN main.Positions AS p ON p.position_id = pl.position_id ",
      "JOIN src.DatasetSample AS ds ON ds.sample_id = pl.sample_ref_id ",
      "JOIN src.Datasets AS d ON d.dataset_id = ds.dataset_id ",
      "ORDER BY pl.position_id, pl.sample_ref_id"
    )
  ) |>
  tibble::as_tibble()

data_probe_ages <-
  DBI::dbGetQuery(
    con_probe_read,
    "SELECT sample_id, age FROM src.Samples ORDER BY sample_id"
  ) |>
  tibble::as_tibble()

DBI::dbDisconnect(con_probe_read)

# The same geodesic distance as v1 (geosphere::distGeo, in metres)
data_probe_links <-
  data_probe_links |>
  dplyr::mutate(
    distance_in_m = geosphere::distGeo(
      p1 = base::cbind(coord_long, coord_lat),
      p2 = base::cbind(grid_long, grid_lat)
    )
  )

data_type_probe_checks <-
  data_probe_links |>
  dplyr::summarise(
    n_links = dplyr::n(),
    n_km_equal_floor = base::sum(
      base::floor(distance_in_m / 1000) == distance_in_km
    ),
    max_distance_in_m = base::max(distance_in_m),
    n_above_49_km = base::sum(distance_in_m >= 49000)
  )

readr::write_csv(
  x = data_type_probe_checks,
  file = base::file.path(path_run, "type_probe_checks.csv")
)

path_type_probes <-
  base::file.path(path_run, "type_probes.sqlite")

con_probe_write <-
  DBI::dbConnect(RSQLite::SQLite(), path_type_probes)

purrr::walk(
  .x = vec_pragma_sql,
  .f = ~ DBI::dbGetQuery(con_probe_write, .x)
)

list_probe_tables <-
  list(
    link_km_integer = list(
      sql = stringr::str_c(
        "CREATE TABLE link_km_integer (position_id INTEGER NOT NULL, ",
        "sample_ref_id INTEGER NOT NULL, distance_in_km INTEGER NOT NULL, ",
        "distance_in_years INTEGER NOT NULL, ",
        "PRIMARY KEY (position_id, sample_ref_id)) WITHOUT ROWID"
      ),
      data = data_probe_links |>
        dplyr::select(
          position_id, sample_ref_id, distance_in_km, distance_in_years
        )
    ),
    link_m_integer = list(
      sql = stringr::str_c(
        "CREATE TABLE link_m_integer (position_id INTEGER NOT NULL, ",
        "sample_ref_id INTEGER NOT NULL, distance_in_m INTEGER NOT NULL, ",
        "distance_in_years INTEGER NOT NULL, ",
        "PRIMARY KEY (position_id, sample_ref_id)) WITHOUT ROWID"
      ),
      data = data_probe_links |>
        dplyr::mutate(
          distance_in_m = base::as.integer(base::floor(distance_in_m))
        ) |>
        dplyr::select(
          position_id, sample_ref_id, distance_in_m, distance_in_years
        )
    ),
    link_km_real = list(
      sql = stringr::str_c(
        "CREATE TABLE link_km_real (position_id INTEGER NOT NULL, ",
        "sample_ref_id INTEGER NOT NULL, distance_in_km REAL NOT NULL, ",
        "distance_in_years INTEGER NOT NULL, ",
        "PRIMARY KEY (position_id, sample_ref_id)) WITHOUT ROWID"
      ),
      data = data_probe_links |>
        dplyr::mutate(distance_in_km = distance_in_m / 1000) |>
        dplyr::select(
          position_id, sample_ref_id, distance_in_km, distance_in_years
        )
    ),
    samples_age_real = list(
      sql = stringr::str_c(
        "CREATE TABLE samples_age_real ",
        "(sample_id INTEGER PRIMARY KEY, age REAL)"
      ),
      data = data_probe_ages
    ),
    samples_age_integer = list(
      sql = stringr::str_c(
        "CREATE TABLE samples_age_integer ",
        "(sample_id INTEGER PRIMARY KEY, age INTEGER)"
      ),
      data = data_probe_ages
    )
  )

purrr::iwalk(
  .x = list_probe_tables,
  .f = ~ {
    DBI::dbExecute(con_probe_write, purrr::chuck(.x, "sql"))

    DBI::dbAppendTable(
      conn = con_probe_write,
      name = .y,
      value = purrr::chuck(.x, "data")
    )
  }
)

DBI::dbDisconnect(con_probe_write)

res_dbstat_probes <-
  processx::run(
    command = path_sqlite_exe,
    args = c("-readonly", "-csv", "-header", path_type_probes, sql_dbstat),
    timeout = 3600
  )

readr::read_csv(
  file = base::I(purrr::chuck(res_dbstat_probes, "stdout")),
  show_col_types = FALSE,
  num_threads = 1L
) |>
  dplyr::mutate(variant = "type_probes", .before = 1L) |>
  readr::write_csv(
    file = base::file.path(path_run, "type_probe_sizes.csv")
  )


#----------------------------------------------------------#
# 7. Record the run -----
#----------------------------------------------------------#

flag_subset_unchanged <-
  base::file.size(path_subset) == size_subset_before &&
  base::file.mtime(path_subset) == mtime_subset_before &&
  base::identical(
    base::readBin(con = path_subset, what = "raw", n = 100L),
    vec_subset_header_before
  )

con_version <-
  DBI::dbConnect(RSQLite::SQLite(), ":memory:")

version_sqlite <-
  DBI::dbGetQuery(con_version, "SELECT sqlite_version() AS v") |>
  dplyr::pull(v)

DBI::dbDisconnect(con_version)

readr::write_csv(
  x = tibble::tibble(
    script = "13_build_schema_prototypes.R",
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    variants = stringr::str_c(vec_variant_names, collapse = " "),
    n_build_repetitions = n_build_repetitions,
    pragmas = stringr::str_c(vec_pragma_sql, collapse = "; "),
    r_version = base::as.character(base::getRversion()),
    rsqlite_version = base::as.character(
      utils::packageVersion("RSQLite")
    ),
    sqlite_version = version_sqlite,
    n_cores = parallel::detectCores(),
    subset_connection = "ATTACH mode=ro",
    subset_unchanged = flag_subset_unchanged,
    all_schema_checks_passed = base::all(
      data_schema_checks |> dplyr::pull(passed)
    )
  ),
  file = base::file.path(path_run, "run_info.csv")
)

assertthat::assert_that(
  base::isTRUE(flag_subset_unchanged),
  msg = "The subset file changed during the run."
)

cli::cli_inform(
  c(
    "v" = "Built {length(vec_variant_names)} schema variants.",
    "i" = "Results in {.path {path_run}}."
  )
)
