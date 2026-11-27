#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Time read queries on the schema prototypes
#            - prototype files read-only; version reader probe
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Time the same read queries on every schema variant built by
#   13_build_schema_prototypes.R, and probe the database-version reader of
#   vaultkeepr:
#   1. Benchmark queries, each run `n_query_repetitions` times, interleaved
#      over the variants, with `EXPLAIN QUERY PLAN` once per variant. A
#      query runs on every variant that has the tables and views it needs:
#      - link reads of the plots in the vaultkeepr subset box, through
#        AbioticDataReference (table or view) and natively through the
#        position tables; the nearest-gridpoint statement of vaultkeepr
#        0.1.0 (taken from question 3, with literal id lists); all links;
#      - bio1 of the linked gridpoints of the same plots, through
#        AbioticData or GridpointValues;
#      - age uncertainty of the fossil pollen samples in the box, as
#        vaultkeepr 0.1.0 sends it (correlated EXISTS) and as an IN query
#        that an index on SampleUncertainty.sample_id can serve;
#      - the datasets in the box, as the CASE filter of vaultkeepr 0.1.0
#        and as a plain BETWEEN filter that the coordinate index can serve;
#      - once per variant: `PRAGMA foreign_key_check`, `quick_check` and
#        `integrity_check`.
#      Each result is fingerprinted, so equal results across variants can
#      be confirmed.
#   2. Version probe: the version reader of the vaultkeepr branch of lane
#      L7 (`prototypes: vaultkeepr_l7_ref`, exported with `git archive`)
#      runs on small new files holding candidate `version_control` tables.
# Prototype files are opened read-only, and their size and modification
#   time are compared before and after. The subset is read only to get the
#   literal id lists. Results go to a new folder `queries_<timestamp>`
#   inside the run folder of script 13.
#
# Usage, from the project root:
#   Rscript R/Analyses/90_Database_research/14_query_schema_prototypes.R
#     <run folder of script 13, for example run_20261120_101500>


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

assertthat::assert_that(
  base::length(vec_args) == 1L,
  stringr::str_detect(purrr::chuck(vec_args, 1L), "^run_[0-9_]+$"),
  msg = "Give the run folder of 13_build_schema_prototypes.R."
)

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_prototypes <-
  purrr::chuck(list_settings, "prototypes")

n_query_repetitions <-
  purrr::chuck(list_settings_prototypes, "n_query_repetitions") |>
  base::as.integer()

path_research <-
  here::here("Data", "Temp", "Database_research")

path_prototypes <-
  base::file.path(path_research, "Prototypes", purrr::chuck(vec_args, 1L))

assertthat::assert_that(
  base::dir.exists(path_prototypes),
  msg = "The run folder of script 13 does not exist."
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

time_run_start <-
  base::Sys.time()

path_out <-
  base::file.path(
    path_prototypes,
    stringr::str_c(
      "queries_", base::format(time_run_start, "%Y%m%d_%H%M%S")
    )
  )

base::dir.create(path = path_out, recursive = TRUE)

vec_variant_names <-
  purrr::chuck(list_settings_prototypes, "variants") |>
  purrr::map_chr(.f = ~ purrr::chuck(.x, "name"))

data_variant_files <-
  tibble::tibble(variant = vec_variant_names) |>
  dplyr::mutate(
    path = base::file.path(
      path_prototypes,
      stringr::str_c(variant, ".sqlite")
    ),
    size_before = base::file.size(path),
    mtime_before = base::file.mtime(path)
  )

assertthat::assert_that(
  base::all(base::file.exists(data_variant_files |> dplyr::pull(path))),
  msg = "A variant file of the run is missing."
)

# The box of the vaultkeepr workloads on the subset
list_box <-
  purrr::chuck(list_settings, "vaultkeepr", "subset_box")

vec_box_long <-
  purrr::chuck(list_box, "long_lim") |>
  base::as.numeric()

vec_box_lat <-
  purrr::chuck(list_box, "lat_lim") |>
  base::as.numeric()


#----------------------------------------------------------#
# 1. Literal id lists from the subset -----
#----------------------------------------------------------#

con_subset <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    path_subset,
    flags = RSQLite::SQLITE_RO
  )

sql_box_samples <-
  stringr::str_c(
    "SELECT ds.sample_id FROM Datasets AS d ",
    "JOIN DatasetSample AS ds ON ds.dataset_id = d.dataset_id ",
    "JOIN DatasetTypeID AS t ON t.dataset_type_id = d.dataset_type_id ",
    "WHERE t.dataset_type = ? ",
    "AND d.coord_long BETWEEN ? AND ? AND d.coord_lat BETWEEN ? AND ? ",
    "ORDER BY ds.sample_id"
  )

vec_box_plot_ids <-
  DBI::dbGetQuery(
    con_subset,
    sql_box_samples,
    params = c(list("vegetation_plot"), vec_box_long, vec_box_lat)
  ) |>
  dplyr::pull(sample_id)

vec_box_gridpoint_ids <-
  DBI::dbGetQuery(
    con_subset,
    sql_box_samples,
    params = c(list("gridpoints"), vec_box_long, vec_box_lat)
  ) |>
  dplyr::pull(sample_id)

DBI::dbDisconnect(con_subset)

vec_replacements <-
  c(
    "<PLOT_IDS>" = stringr::str_c(vec_box_plot_ids, collapse = ", "),
    "<GRIDPOINT_IDS>" = stringr::str_c(vec_box_gridpoint_ids, collapse = ", "),
    "<LONG_MIN>" = base::format(base::min(vec_box_long)),
    "<LONG_MAX>" = base::format(base::max(vec_box_long)),
    "<LAT_MIN>" = base::format(base::min(vec_box_lat)),
    "<LAT_MAX>" = base::format(base::max(vec_box_lat))
  )


#----------------------------------------------------------#
# 2. Benchmark queries -----
#----------------------------------------------------------#

data_queries <-
  tibble::tribble(
    ~query, ~needs, ~n_runs, ~sql_template,
    "links_box_plots",
    "AbioticDataReference",
    n_query_repetitions,
    stringr::str_c(
      "SELECT sample_id, sample_ref_id, distance_in_km, ",
      "distance_in_years FROM AbioticDataReference ",
      "WHERE sample_id IN (<PLOT_IDS>)"
    ),
    "links_box_plots_native",
    "SamplePosition PositionLink",
    n_query_repetitions,
    stringr::str_c(
      "SELECT sp.sample_id, pl.* FROM SamplePosition AS sp ",
      "JOIN PositionLink AS pl ON pl.position_id = sp.position_id ",
      "WHERE sp.sample_id IN (<PLOT_IDS>)"
    ),
    # The statement of vaultkeepr 0.1.0 for the nearest gridpoint (a02)
    "nearest_box_plots_vaultkeepr",
    "AbioticDataReference",
    n_query_repetitions,
    stringr::str_c(
      "SELECT DISTINCT `sample_ref_id` FROM ( SELECT `sample_id`, ",
      "`sample_ref_id`, ROW_NUMBER() OVER (PARTITION BY `sample_id` ",
      "ORDER BY `sample_id`) AS `col03` FROM ( SELECT `sample_id`, ",
      "`sample_ref_id`, `distance_in_km`, `distance_in_years`, ",
      "MIN(`distance_in_years`) OVER (PARTITION BY `sample_id`) AS `col02` ",
      "FROM ( SELECT *, MIN(`distance_in_km`) OVER (PARTITION BY ",
      "`sample_id`) AS `col01` FROM `AbioticDataReference` WHERE ",
      "(`sample_id` IN (<PLOT_IDS>)) AND (`sample_ref_id` IN ",
      "(<GRIDPOINT_IDS>)) AND (`distance_in_km` <= 50.0) AND ",
      "(`distance_in_years` <= 5000.0) ) AS `q01` WHERE (`distance_in_km` ",
      "= `col01`) ) AS `q01` WHERE (`distance_in_years` = `col02`) ) AS ",
      "`q01` WHERE (`col03` = 1)"
    ),
    "links_all",
    "AbioticDataReference",
    n_query_repetitions,
    stringr::str_c(
      "SELECT count(*) AS n, sum(distance_in_km) AS km, ",
      "sum(distance_in_years) AS years FROM AbioticDataReference"
    ),
    "bio1_box_plots",
    "AbioticDataReference AbioticData AbioticVariable",
    n_query_repetitions,
    stringr::str_c(
      "SELECT l.sample_id, avg(a.abiotic_value) AS bio1 ",
      "FROM AbioticDataReference AS l ",
      "JOIN AbioticData AS a ON a.sample_id = l.sample_ref_id ",
      "WHERE l.sample_id IN (<PLOT_IDS>) AND a.abiotic_variable_id = ",
      "(SELECT abiotic_variable_id FROM AbioticVariable ",
      "WHERE abiotic_variable_name = 'bio1') GROUP BY l.sample_id"
    ),
    "bio1_box_plots_gridpoint_tables",
    "SamplePosition PositionLink GridpointValues AbioticVariable",
    n_query_repetitions,
    stringr::str_c(
      "SELECT sp.sample_id, avg(g.abiotic_value) AS bio1 ",
      "FROM SamplePosition AS sp ",
      "JOIN PositionLink AS pl ON pl.position_id = sp.position_id ",
      "JOIN GridpointValues AS g ON g.gridpoint_id = pl.gridpoint_id ",
      "WHERE sp.sample_id IN (<PLOT_IDS>) AND g.abiotic_variable_id = ",
      "(SELECT abiotic_variable_id FROM AbioticVariable ",
      "WHERE abiotic_variable_name = 'bio1') GROUP BY sp.sample_id"
    ),
    # The statement of vaultkeepr 0.1.0 for get_age_uncertainty() (a06)
    "age_uncertainty_vaultkeepr",
    "SampleUncertainty Samples Datasets DatasetSample DatasetTypeID",
    n_query_repetitions,
    stringr::str_c(
      "SELECT `sample_name`, `iteration`, `age_uncertainty` FROM ( SELECT ",
      "`sample_id`, `iteration`, `age` AS `age_uncertainty` FROM ",
      "`SampleUncertainty` WHERE EXISTS ( SELECT 1 FROM ( SELECT *, CASE ",
      "WHEN ((`age` IS NULL) AND (`dataset_type` IN ",
      "('fossil_pollen_archive'))) THEN 0 WHEN ((`age` < 0.0) AND ",
      "(`dataset_type` IN ('fossil_pollen_archive'))) THEN 0 WHEN ((`age` ",
      "> 8000.0) AND (`dataset_type` IN ('fossil_pollen_archive'))) THEN 0 ",
      "ELSE 1 END AS `keep` FROM ( SELECT `...1`.*, ",
      "`DatasetSample`.`sample_id` AS `sample_id`, `sample_name`, ",
      "`sample_details`, `age`, `sample_size_id` FROM ( SELECT ",
      "`dataset_id`, `dataset_name`, `data_source_id`, `dataset_type_id`, ",
      "`data_source_type_id`, `coord_long`, `coord_lat`, ",
      "`sampling_method_id`, `dataset_type` FROM ( SELECT *, CASE WHEN ",
      "((`coord_long` IS NULL) AND (`dataset_type` IN ",
      "('fossil_pollen_archive'))) THEN 0 WHEN ((`coord_lat` IS NULL) AND ",
      "(`dataset_type` IN ('fossil_pollen_archive'))) THEN 0 WHEN ",
      "((`coord_long` < <LONG_MIN>) AND (`dataset_type` IN ",
      "('fossil_pollen_archive'))) THEN 0 WHEN ((`coord_long` > ",
      "<LONG_MAX>) AND (`dataset_type` IN ('fossil_pollen_archive'))) ",
      "THEN 0 WHEN ((`coord_lat` < <LAT_MIN>) AND (`dataset_type` IN ",
      "('fossil_pollen_archive'))) THEN 0 WHEN ((`coord_lat` > <LAT_MAX>) ",
      "AND (`dataset_type` IN ('fossil_pollen_archive'))) THEN 0 ELSE 1 ",
      "END AS `keep` FROM ( SELECT `Datasets`.*, `dataset_type` FROM ",
      "`Datasets` LEFT JOIN `DatasetTypeID` ON (`Datasets`.",
      "`dataset_type_id` = `DatasetTypeID`.`dataset_type_id`) WHERE ",
      "(`DatasetTypeID`.`dataset_type` IN ('fossil_pollen_archive')) ) AS ",
      "`q01` ) AS `q01` WHERE (`keep` = 1) ) AS `...1` INNER JOIN ",
      "`DatasetSample` ON (`...1`.`dataset_id` = ",
      "`DatasetSample`.`dataset_id`) INNER JOIN `Samples` ON ",
      "(`DatasetSample`.`sample_id` = `Samples`.`sample_id`) ) AS `q01` ) ",
      "AS `RHS` WHERE (`SampleUncertainty`.`sample_id` = `RHS`.",
      "`sample_id`) AND (`RHS`.`keep` = 1) ) ) AS `LHS` LEFT JOIN ",
      "`Samples` ON (`LHS`.`sample_id` = `Samples`.`sample_id`)"
    ),
    "age_uncertainty_in",
    "SampleUncertainty Samples Datasets DatasetSample DatasetTypeID",
    n_query_repetitions,
    stringr::str_c(
      "SELECT s.sample_name, su.iteration, su.age AS age_uncertainty ",
      "FROM SampleUncertainty AS su ",
      "JOIN Samples AS s ON s.sample_id = su.sample_id ",
      "WHERE su.sample_id IN (SELECT ds.sample_id FROM Datasets AS d ",
      "JOIN DatasetSample AS ds ON ds.dataset_id = d.dataset_id ",
      "JOIN Samples AS s2 ON s2.sample_id = ds.sample_id ",
      "WHERE d.dataset_type_id = (SELECT dataset_type_id FROM ",
      "DatasetTypeID WHERE dataset_type = 'fossil_pollen_archive') ",
      "AND d.coord_long BETWEEN <LONG_MIN> AND <LONG_MAX> ",
      "AND d.coord_lat BETWEEN <LAT_MIN> AND <LAT_MAX> ",
      "AND s2.age BETWEEN 0 AND 8000)"
    ),
    # The dataset step of select_dataset_by_geo() in vaultkeepr 0.1.0
    "box_datasets_vaultkeepr",
    "Datasets DatasetTypeID",
    n_query_repetitions,
    stringr::str_c(
      "SELECT `dataset_id` FROM ( SELECT *, CASE WHEN ((`coord_long` IS ",
      "NULL) AND (`dataset_type` IN (<TYPES>))) THEN 0 WHEN ((`coord_lat` ",
      "IS NULL) AND (`dataset_type` IN (<TYPES>))) THEN 0 WHEN ",
      "((`coord_long` < <LONG_MIN>) AND (`dataset_type` IN (<TYPES>))) ",
      "THEN 0 WHEN ((`coord_long` > <LONG_MAX>) AND (`dataset_type` IN ",
      "(<TYPES>))) THEN 0 WHEN ((`coord_lat` < <LAT_MIN>) AND ",
      "(`dataset_type` IN (<TYPES>))) THEN 0 WHEN ((`coord_lat` > ",
      "<LAT_MAX>) AND (`dataset_type` IN (<TYPES>))) THEN 0 ELSE 1 END ",
      "AS `keep` FROM ( SELECT `Datasets`.*, `dataset_type` FROM ",
      "`Datasets` LEFT JOIN `DatasetTypeID` ON (`Datasets`.",
      "`dataset_type_id` = `DatasetTypeID`.`dataset_type_id`) WHERE ",
      "(`DatasetTypeID`.`dataset_type` IN (<TYPES>)) ) AS `q01` ) AS ",
      "`q01` WHERE (`keep` = 1)"
    ),
    "box_datasets_between",
    "Datasets DatasetTypeID",
    n_query_repetitions,
    stringr::str_c(
      "SELECT d.dataset_id FROM Datasets AS d ",
      "WHERE d.coord_long BETWEEN <LONG_MIN> AND <LONG_MAX> ",
      "AND d.coord_lat BETWEEN <LAT_MIN> AND <LAT_MAX> ",
      "AND d.dataset_type_id IN (SELECT dataset_type_id FROM ",
      "DatasetTypeID WHERE dataset_type IN (<TYPES>))"
    ),
    "foreign_key_check",
    "",
    1L,
    "PRAGMA foreign_key_check",
    "quick_check",
    "",
    1L,
    "PRAGMA quick_check",
    "integrity_check",
    "",
    1L,
    "PRAGMA integrity_check"
  ) |>
  dplyr::mutate(
    sql = sql_template |>
      stringr::str_replace_all(
        pattern = stringr::fixed("<TYPES>"),
        replacement = stringr::str_c(
          "'vegetation_plot', 'fossil_pollen_archive', 'gridpoints'"
        )
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed("<PLOT_IDS>"),
        replacement = purrr::chuck(vec_replacements, "<PLOT_IDS>")
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed("<GRIDPOINT_IDS>"),
        replacement = purrr::chuck(vec_replacements, "<GRIDPOINT_IDS>")
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed("<LONG_MIN>"),
        replacement = purrr::chuck(vec_replacements, "<LONG_MIN>")
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed("<LONG_MAX>"),
        replacement = purrr::chuck(vec_replacements, "<LONG_MAX>")
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed("<LAT_MIN>"),
        replacement = purrr::chuck(vec_replacements, "<LAT_MIN>")
      ) |>
      stringr::str_replace_all(
        pattern = stringr::fixed("<LAT_MAX>"),
        replacement = purrr::chuck(vec_replacements, "<LAT_MAX>")
      ),
    needs = stringr::str_split(needs, " ") |>
      purrr::map(.f = ~ purrr::keep(.x, .p = base::nzchar))
  ) |>
  dplyr::select(-sql_template)

assertthat::assert_that(
  !base::any(
    stringr::str_detect(data_queries |> dplyr::pull(sql), "<[A-Z_]+>")
  ),
  msg = "A placeholder of a benchmark query was not replaced."
)

readr::write_csv(
  x = data_queries |>
    dplyr::mutate(
      needs = purrr::map_chr(
        .x = needs,
        .f = ~ stringr::str_c(.x, collapse = " ")
      )
    ),
  file = base::file.path(path_out, "queries.csv")
)

# Tables and views of each variant
data_variant_objects <-
  data_variant_files |>
  dplyr::mutate(
    objects = purrr::map(
      .x = path,
      .f = ~ {
        con_objects <-
          DBI::dbConnect(
            RSQLite::SQLite(),
            .x,
            flags = RSQLite::SQLITE_RO
          )

        vec_objects <-
          DBI::dbGetQuery(
            con_objects,
            stringr::str_c(
              "SELECT name FROM sqlite_schema ",
              "WHERE type IN ('table', 'view')"
            )
          ) |>
          dplyr::pull(name)

        DBI::dbDisconnect(con_objects)

        vec_objects
      }
    )
  ) |>
  dplyr::select(variant, objects)

# Every query on every variant that has what it needs; repetitions are the
#   outer loop and the variants the middle loop
data_runs <-
  tidyr::expand_grid(
    repetition = base::seq_len(n_query_repetitions),
    variant = vec_variant_names,
    query = data_queries |> dplyr::pull(query)
  ) |>
  dplyr::left_join(data_queries, by = "query") |>
  dplyr::left_join(data_variant_objects, by = "variant") |>
  dplyr::filter(
    repetition <= n_runs,
    purrr::map2_lgl(.x = needs, .y = objects, .f = ~ base::all(.x %in% .y))
  ) |>
  dplyr::left_join(
    data_variant_files |> dplyr::select(variant, path),
    by = "variant"
  )

data_query_times <-
  data_runs |>
  dplyr::mutate(
    result = purrr::pmap(
      .l = list(path, sql, repetition, variant, query),
      .f = ~ {
        # cli templates cannot start with a dot, so the arguments get names
        n_repetition_now <- ..3

        name_variant_now <- ..4

        name_query_now <- ..5

        cli::cli_inform(
          "{name_query_now} on {name_variant_now}, {n_repetition_now}."
        )

        con_query <-
          DBI::dbConnect(
            RSQLite::SQLite(),
            ..1,
            flags = RSQLite::SQLITE_RO
          )

        time_query_start <-
          base::Sys.time()

        data_result <-
          DBI::dbGetQuery(con_query, ..2)

        seconds_query <-
          base::difftime(
            base::Sys.time(),
            time_query_start,
            units = "secs"
          ) |>
          base::as.numeric()

        data_plan <-
          if (
            n_repetition_now == 1L &&
              !stringr::str_detect(..2, "^PRAGMA")
          ) {
            DBI::dbGetQuery(
              con_query,
              stringr::str_c("EXPLAIN QUERY PLAN ", ..2)
            ) |>
              tibble::as_tibble()
          } else {
            NULL
          }

        DBI::dbDisconnect(con_query)

        # Values only, sorted, so that results with renamed columns compare
        text_hash <-
          data_result |>
          tibble::as_tibble() |>
          dplyr::arrange(dplyr::across(dplyr::everything())) |>
          base::as.list() |>
          base::unname() |>
          rlang::hash()

        tibble::tibble(
          seconds = seconds_query,
          n_rows = base::nrow(data_result),
          result_hash = text_hash,
          first_value = data_result |>
            purrr::chuck(1L) |>
            utils::head(1L) |>
            base::as.character() |>
            dplyr::first(default = NA_character_),
          plan = list(data_plan)
        )
      }
    )
  ) |>
  dplyr::select(variant, query, repetition, result) |>
  tidyr::unnest(result)

readr::write_csv(
  x = data_query_times |> dplyr::select(-plan),
  file = base::file.path(path_out, "query_times.csv")
)

data_query_times |>
  dplyr::filter(repetition == 1L) |>
  dplyr::select(variant, query, plan) |>
  dplyr::filter(!purrr::map_lgl(plan, base::is.null)) |>
  tidyr::unnest(plan) |>
  readr::write_csv(file = base::file.path(path_out, "query_plans.csv"))

data_query_summary <-
  data_query_times |>
  dplyr::summarise(
    n_runs = dplyr::n(),
    seconds_median = stats::median(seconds),
    seconds_min = base::min(seconds),
    seconds_max = base::max(seconds),
    n_rows = dplyr::first(n_rows),
    n_result_hashes = dplyr::n_distinct(result_hash),
    result_hash = dplyr::first(result_hash),
    .by = c(variant, query)
  ) |>
  dplyr::mutate(
    flag_same_result_as_v1 = result_hash == dplyr::first(
      result_hash[variant == "v1"],
      default = NA_character_
    ),
    .by = query
  )

readr::write_csv(
  x = data_query_summary,
  file = base::file.path(path_out, "query_summary.csv")
)


#----------------------------------------------------------#
# 3. Version reader probe -----
#----------------------------------------------------------#

path_vaultkeepr_repo <-
  here::here(purrr::chuck(list_settings, "vaultkeepr", "repo"))

name_l7_ref <-
  purrr::chuck(list_settings_prototypes, "vaultkeepr_l7_ref")

sha_l7 <-
  processx::run(
    command = "git",
    args = c("-C", path_vaultkeepr_repo, "rev-parse", name_l7_ref)
  ) |>
  purrr::chuck("stdout") |>
  stringr::str_squish()

path_l7_src <-
  base::file.path(path_out, "vaultkeepr_l7_src")

base::dir.create(path_l7_src)

path_l7_tar <-
  base::file.path(path_out, "vaultkeepr_l7.tar")

processx::run(
  command = "git",
  args = c(
    "-C", path_vaultkeepr_repo,
    "archive", "--format=tar",
    stringr::str_c("--output=", path_l7_tar),
    sha_l7, "R/vegvault_version.R"
  )
)

utils::untar(tarfile = path_l7_tar, exdir = path_l7_src)

# The reader file defines detect_vegvault_version(); it uses the magrittr
#   pipe, which the environment provides
env_l7 <-
  base::new.env()

base::assign(x = "%>%", value = magrittr::`%>%`, envir = env_l7)

base::sys.source(
  file = base::file.path(path_l7_src, "R", "vegvault_version.R"),
  envir = env_l7
)

fn_detect_version <-
  base::get(x = "detect_vegvault_version", envir = env_l7)

# The version rows of config.yml (database: versions) in their order
vec_versions <-
  c("0.0.2", "0.0.3", "0.0.4", "1.0.0", "2.0.0")

sql_version_v1 <-
  stringr::str_c(
    "CREATE TABLE version_control (id INTEGER PRIMARY KEY, ",
    "version TEXT, update_date TEXT DEFAULT CURRENT_DATE, changelog TEXT)"
  )

# Candidate hook: build columns on the version row and one row per
#   producer pin; the values are placeholders
sql_version_extended <-
  stringr::str_c(
    "CREATE TABLE version_control (id INTEGER PRIMARY KEY, ",
    "version TEXT NOT NULL UNIQUE, update_date TEXT, changelog TEXT, ",
    "build_profile TEXT, git_commit TEXT, manifest_sha256 TEXT)"
  )

sql_build_producers <-
  stringr::str_c(
    "CREATE TABLE BuildProducers (version_id INTEGER NOT NULL ",
    "REFERENCES version_control (id), producer TEXT NOT NULL, ",
    "tag TEXT NOT NULL, commit_sha TEXT NOT NULL, ",
    "PRIMARY KEY (version_id, producer)) WITHOUT ROWID"
  )

data_version_cases <-
  tibble::tribble(
    ~case, ~ddl, ~versions_in_insert_order,
    "v1_table_rows_in_config_order",
    list(sql_version_v1),
    vec_versions,
    "extended_table_rows_in_config_order",
    list(sql_version_extended, sql_build_producers),
    vec_versions,
    "v1_table_new_row_written_first",
    list(sql_version_v1),
    c("2.0.0", "0.0.2", "0.0.3", "0.0.4", "1.0.0")
  ) |>
  dplyr::mutate(
    expected = "2.0.0",
    returned = purrr::pmap_chr(
      .l = list(case, ddl, versions_in_insert_order),
      .f = ~ {
        path_case <-
          base::file.path(path_out, stringr::str_c("version_", ..1, ".sqlite"))

        con_case_write <-
          DBI::dbConnect(RSQLite::SQLite(), path_case)

        purrr::walk(
          .x = ..2,
          .f = ~ DBI::dbExecute(con_case_write, .x)
        )

        purrr::walk(
          .x = ..3,
          .f = ~ DBI::dbExecute(
            con_case_write,
            "INSERT INTO version_control (version) VALUES (?)",
            params = list(.x)
          )
        )

        DBI::dbDisconnect(con_case_write)

        con_case_read <-
          DBI::dbConnect(
            RSQLite::SQLite(),
            path_case,
            flags = RSQLite::SQLITE_RO
          )

        text_returned <-
          fn_detect_version(con_case_read)

        DBI::dbDisconnect(con_case_read)

        text_returned
      }
    ),
    passed = returned == expected,
    versions_in_insert_order = purrr::map_chr(
      .x = versions_in_insert_order,
      .f = ~ stringr::str_c(.x, collapse = " ")
    ),
    l7_ref = name_l7_ref,
    l7_sha = sha_l7
  ) |>
  dplyr::select(-ddl)

readr::write_csv(
  x = data_version_cases,
  file = base::file.path(path_out, "version_probe.csv")
)


#----------------------------------------------------------#
# 4. Record the run -----
#----------------------------------------------------------#

data_variant_files_after <-
  data_variant_files |>
  dplyr::mutate(
    unchanged = base::file.size(path) == size_before &
      base::file.mtime(path) == mtime_before
  )

readr::write_csv(
  x = tibble::tibble(
    script = "14_query_schema_prototypes.R",
    prototype_run = purrr::chuck(vec_args, 1L),
    run_started = base::format(time_run_start, "%Y-%m-%d %H:%M:%S"),
    run_seconds = base::difftime(
      base::Sys.time(),
      time_run_start,
      units = "secs"
    ) |>
      base::as.numeric(),
    n_query_repetitions = n_query_repetitions,
    n_box_plots = base::length(vec_box_plot_ids),
    n_box_gridpoints = base::length(vec_box_gridpoint_ids),
    connection = "RSQLite SQLITE_RO, default cache",
    r_version = base::as.character(base::getRversion()),
    rsqlite_version = base::as.character(
      utils::packageVersion("RSQLite")
    ),
    files_unchanged = base::all(
      data_variant_files_after |> dplyr::pull(unchanged)
    )
  ),
  file = base::file.path(path_out, "run_info.csv")
)

assertthat::assert_that(
  base::all(data_variant_files_after |> dplyr::pull(unchanged)),
  msg = "A prototype file changed while it was read."
)

n_variants <-
  base::length(vec_variant_names)

cli::cli_inform(
  c(
    "v" = "Timed the benchmark queries on {n_variants} variants.",
    "i" = "Results in {.path {path_out}}."
  )
)
