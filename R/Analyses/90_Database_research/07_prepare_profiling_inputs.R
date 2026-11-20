#----------------------------------------------------------#
#
#
#                       VegVault
#
#      Prepare the inputs for profiling the v1 gridpoint stage
#        - v1.1.0 abiotic inputs and pre-gridpoint databases
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Prepare everything 08_profile_v1_gridpoints.R needs, without touching
#   v1.0.0:
#   1. The gridpoint coordinates and ages, and the current-climate bio1
#      artefact, read once from the v1.1.0 abiotic artefacts in the local
#      VegVault-abiotic_data checkout. Those are legacy `qs` files, so
#      07a_read_v1_abiotic_inputs_legacy.R reads them with R 4.5.1.
#   2. For each nested profiling box, a database in the state just before
#      the v1 gridpoint stage: the v1 schema with the non-gridpoint
#      datasets of the box and their rows, copied from the regional
#      subset (opened read-only) with their original ids. Gridpoint
#      datasets, abiotic values, and links are left out. The lookup tables
#      are copied whole, so they keep the gridpoint lookup rows (dataset
#      type 4 and source type 5), which the stage hard-codes. Indexes are
#      created as in v1; no statistics are gathered, as in a fresh build.
#   Each output is written under a temporary name and renamed when
#   complete; existing outputs are kept, so a rerun only adds what is
#   missing.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration
source(
  here::here("R/00_Config_file.R")
)

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_subset <-
  purrr::chuck(list_settings, "subset")

list_settings_profiling <-
  purrr::chuck(list_settings, "profiling")

path_research <-
  here::here("Data", "Temp", "Database_research")

path_subset <-
  base::file.path(
    path_research,
    "Subset",
    stringr::str_c(
      "v1_subset_",
      purrr::chuck(list_settings_subset, "box_name"),
      ".sqlite"
    )
  )

path_profiling <-
  base::file.path(path_research, "Profiling")

path_inputs <-
  base::file.path(path_profiling, "Inputs")

base::dir.create(
  path = path_inputs,
  recursive = TRUE,
  showWarnings = FALSE
)

path_legacy_script <-
  here::here(
    "R/Analyses/90_Database_research/07a_read_v1_abiotic_inputs_legacy.R"
  )

path_artefacts <-
  here::here(purrr::chuck(list_settings_profiling, "abiotic_artefact_dir"))

vec_artefact_files <-
  c(
    purrr::chuck(list_settings_profiling, "paleo_bio01_files") |>
      base::unlist(),
    purrr::chuck(list_settings_profiling, "neo_bio01_file")
  )

vec_input_files <-
  base::file.path(
    path_inputs,
    c(
      "gridpoint_ages.rds",
      "gridpoint_coords_global.rds",
      "chelsa_neo_bio01_global.rds"
    )
  )

# Tables with rows per dataset or per sample of the box; all other tables
#   are copied whole, except the abiotic values and the links
data_tables_by_key <-
  tibble::tribble(
    ~table_name, ~key_column,
    "DatasetReferences", "dataset_id",
    "TraitsValue", "dataset_id",
    "SampleTaxa", "sample_id",
    "SampleUncertainty", "sample_id",
    "SampleReference", "sample_id"
  )

vec_tables_left_empty <-
  c("AbioticData", "AbioticDataReference")

vec_tables_selected <-
  c(
    "Datasets",
    "DatasetSample",
    "Samples",
    data_tables_by_key |>
      dplyr::pull(table_name),
    vec_tables_left_empty
  )

assertthat::assert_that(
  base::file.exists(path_subset),
  msg = "The regional subset does not exist; run 04_extract_v1_subset.R."
)

assertthat::assert_that(
  base::all(
    base::file.exists(base::file.path(path_artefacts, vec_artefact_files))
  ),
  msg = "The v1.1.0 abiotic artefacts are missing from the local checkout."
)


#----------------------------------------------------------#
# 1. Read the v1.1.0 abiotic inputs with legacy R -----
#----------------------------------------------------------#

if (
  base::isFALSE(base::all(base::file.exists(vec_input_files)))
) {
  time_legacy_start <-
    base::Sys.time()

  # Run from the temporary folder with `--vanilla`, so no project profile
  #   and no renv is loaded
  res_legacy <-
    processx::run(
      command = purrr::chuck(list_settings_profiling, "legacy_rscript"),
      args = c(
        "--vanilla",
        path_legacy_script,
        here::here(purrr::chuck(list_settings_profiling, "legacy_library")),
        path_artefacts,
        path_inputs,
        vec_artefact_files
      ),
      wd = base::tempdir(),
      timeout = 3600,
      error_on_status = TRUE
    )

  readr::write_csv(
    x = tibble::tibble(
      seconds = base::difftime(
        base::Sys.time(),
        time_legacy_start,
        units = "secs"
      ) |>
        base::as.numeric(),
      stdout = purrr::chuck(res_legacy, "stdout") |>
        stringr::str_squish()
    ),
    file = base::file.path(path_inputs, "legacy_read.csv")
  )
}

data_input_checksums <-
  tibble::tibble(
    file = c(vec_artefact_files, base::basename(vec_input_files)),
    md5 = c(
      tools::md5sum(base::file.path(path_artefacts, vec_artefact_files)),
      tools::md5sum(vec_input_files)
    ) |>
      base::unname(),
    size_bytes = c(
      base::file.size(base::file.path(path_artefacts, vec_artefact_files)),
      base::file.size(vec_input_files)
    )
  )

readr::write_csv(
  x = data_input_checksums,
  file = base::file.path(path_inputs, "input_checksums.csv")
)


#----------------------------------------------------------#
# 2. Build one pre-gridpoint database per box -----
#----------------------------------------------------------#

vec_box_names <-
  purrr::chuck(list_settings_profiling, "boxes") |>
  base::names()

purrr::walk(
  .x = vec_box_names,
  .f = ~ {
    name_box <- .x

    list_box <-
      purrr::chuck(list_settings_profiling, "boxes", name_box)

    path_box <-
      base::file.path(path_profiling, name_box)

    path_template <-
      base::file.path(path_box, "pre_gridpoints.sqlite")

    path_template_partial <-
      stringr::str_c(path_template, ".partial")

    if (
      base::file.exists(path_template)
    ) {
      cli::cli_inform("Box {name_box}: database exists, kept.")
    } else {
      base::dir.create(
        path = path_box,
        recursive = TRUE,
        showWarnings = FALSE
      )

      # A leftover partial file is from an interrupted run of this script
      base::unlink(path_template_partial)

      time_box_start <-
        base::Sys.time()

      con_source <-
        DBI::dbConnect(
          drv = RSQLite::SQLite(),
          dbname = path_subset,
          flags = RSQLite::SQLITE_RO
        )

      con_template <-
        DBI::dbConnect(
          drv = RSQLite::SQLite(),
          dbname = path_template_partial
        )

      data_table_rows <-
        tryCatch(
          expr = {
            # The disposable file needs no crash safety while it is written
            DBI::dbExecute(
              conn = con_template,
              statement = "PRAGMA journal_mode = OFF"
            )

            DBI::dbExecute(
              conn = con_template,
              statement = "PRAGMA synchronous = OFF"
            )

            data_schema_v1 <-
              DBI::dbGetQuery(
                conn = con_source,
                statement = stringr::str_c(
                  "SELECT type, name, sql FROM sqlite_master ",
                  "WHERE sql IS NOT NULL AND name NOT LIKE 'sqlite_%'"
                )
              ) |>
              tibble::as_tibble()

            purrr::walk(
              .x = data_schema_v1 |>
                dplyr::filter(type == "table") |>
                dplyr::pull(sql),
              .f = ~ DBI::dbExecute(conn = con_template, statement = .x)
            )

            # Non-gridpoint datasets of the box and their samples
            data_datasets_box <-
              DBI::dbGetQuery(
                conn = con_source,
                statement = stringr::str_c(
                  "SELECT * FROM Datasets ",
                  "WHERE dataset_type_id != 4 ",
                  "AND coord_long BETWEEN ? AND ? ",
                  "AND coord_lat BETWEEN ? AND ?"
                ),
                params = list(
                  purrr::chuck(list_box, "lon_min"),
                  purrr::chuck(list_box, "lon_max"),
                  purrr::chuck(list_box, "lat_min"),
                  purrr::chuck(list_box, "lat_max")
                )
              ) |>
              tibble::as_tibble()

            vec_dataset_id_box <-
              data_datasets_box |>
              dplyr::pull(dataset_id)

            data_dataset_sample_box <-
              DBI::dbGetQuery(
                conn = con_source,
                statement = "SELECT * FROM DatasetSample WHERE dataset_id = ?",
                params = list(vec_dataset_id_box)
              ) |>
              tibble::as_tibble()

            vec_sample_id_box <-
              data_dataset_sample_box |>
              dplyr::pull(sample_id) |>
              base::unique()

            data_samples_box <-
              DBI::dbGetQuery(
                conn = con_source,
                statement = "SELECT * FROM Samples WHERE sample_id = ?",
                params = list(vec_sample_id_box)
              ) |>
              tibble::as_tibble()

            list_key_ids <-
              list(
                dataset_id = vec_dataset_id_box,
                sample_id = vec_sample_id_box
              )

            list_tables_by_key <-
              data_tables_by_key |>
              dplyr::mutate(
                data = purrr::map2(
                  .x = table_name,
                  .y = key_column,
                  .f = ~ DBI::dbGetQuery(
                    conn = con_source,
                    statement = stringr::str_c(
                      "SELECT * FROM ", .x, " WHERE ", .y, " = ?"
                    ),
                    params = list(purrr::chuck(list_key_ids, .y))
                  ) |>
                    tibble::as_tibble()
                )
              ) |>
              dplyr::select(table_name, data) |>
              tibble::deframe()

            list_tables_whole <-
              data_schema_v1 |>
              dplyr::filter(
                type == "table",
                !name %in% vec_tables_selected
              ) |>
              dplyr::pull(name) |>
              rlang::set_names() |>
              purrr::map(
                .f = ~ DBI::dbReadTable(conn = con_source, name = .x) |>
                  tibble::as_tibble()
              )

            list_tables_box <-
              c(
                list_tables_whole,
                list(
                  Datasets = data_datasets_box,
                  DatasetSample = data_dataset_sample_box,
                  Samples = data_samples_box
                ),
                list_tables_by_key
              )

            DBI::dbWithTransaction(
              conn = con_template,
              code = purrr::iwalk(
                .x = list_tables_box,
                .f = ~ DBI::dbAppendTable(
                  conn = con_template,
                  name = .y,
                  value = .x
                )
              )
            )

            # Indexes as in v1, which creates them with the tables
            purrr::walk(
              .x = data_schema_v1 |>
                dplyr::filter(type == "index") |>
                dplyr::pull(sql),
              .f = ~ DBI::dbExecute(conn = con_template, statement = .x)
            )

            value_quick_check <-
              DBI::dbGetQuery(
                conn = con_template,
                statement = "PRAGMA quick_check"
              ) |>
              dplyr::pull(var = 1)

            assertthat::assert_that(
              base::identical(value_quick_check, "ok"),
              msg = "The quick check of the box database failed."
            )

            purrr::imap(
              .x = list_tables_box,
              .f = ~ tibble::tibble(
                table_name = .y,
                n_rows = base::nrow(.x)
              )
            ) |>
              dplyr::bind_rows()
          },
          finally = {
            DBI::dbDisconnect(con_source)
            DBI::dbDisconnect(con_template)
          }
        )

      assertthat::assert_that(
        base::file.rename(from = path_template_partial, to = path_template),
        msg = "Renaming the box database failed."
      )

      readr::write_csv(
        x = data_table_rows |>
          dplyr::mutate(
            box_name = name_box,
            seconds_build = base::difftime(
              base::Sys.time(),
              time_box_start,
              units = "secs"
            ) |>
              base::as.numeric(),
            size_bytes = base::file.size(path_template)
          ),
        file = base::file.path(path_box, "pre_gridpoints_rows.csv")
      )

      cli::cli_inform("Box {name_box}: database built.")
    }
  }
)

cli::cli_inform(
  c(
    "v" = "Profiling inputs prepared.",
    "i" = "Saved to {.path {path_profiling}}."
  )
)
