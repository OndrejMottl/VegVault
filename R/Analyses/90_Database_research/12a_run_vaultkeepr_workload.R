#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Run one vaultkeepr workload and log its queries
#         - called by 12_profile_vaultkeepr_queries.R only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Run one workload (a vaultkeepr pipeline taken from its vignettes) once,
#   in its own R process, against the database named by the target, opened
#   read-only. Instead of open_vault(), which opens the file read-write,
#   the read-only connection is wrapped in the same `vault_pipe` structure.
#   Every SQL statement RSQLite runs is logged as one JSON line: when its
#   result is created (with the statement and the vaultkeepr functions on
#   the call stack) and when it is released. The last line summarises the
#   run. The path of the database is never printed.
#
# Arguments: target ("v1", "subset" or "prototype:<run folder>/<variant>",
#   see 12_profile_vaultkeepr_queries.R), workload name, repetition,
#   folder of the vaultkeepr source, log file.


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

assertthat::assert_that(
  base::length(vec_args) == 5L,
  msg = "Five arguments are expected."
)

name_target <-
  purrr::chuck(vec_args, 1L)

name_workload <-
  purrr::chuck(vec_args, 2L)

n_repetition <-
  purrr::chuck(vec_args, 3L) |>
  base::as.integer()

path_vaultkeepr <-
  purrr::chuck(vec_args, 4L)

path_log <-
  purrr::chuck(vec_args, 5L)

list_settings <-
  yaml::read_yaml(
    here::here("R/Analyses/90_Database_research/research_settings.yml")
  )

list_settings_vaultkeepr <-
  purrr::chuck(list_settings, "vaultkeepr")

pattern_prototype <-
  "^prototype:(run_[0-9_]+)/([a-z0-9_]+)$"

assertthat::assert_that(
  name_target %in% c("v1", "subset") ||
    stringr::str_detect(name_target, pattern_prototype),
  msg = "The target must be `v1`, `subset` or `prototype:<run>/<variant>`."
)

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

# The vignette box of each workload; workloads without a box use the whole
#   database
data_workload_boxes <-
  tibble::tribble(
    ~workload, ~box_name,
    "a01_taxa_distribution", "west_north_america",
    "a01_taxon_names", "west_north_america",
    "a02_vegetation_climate", "europe",
    "a02_abiotic_mean", "europe",
    "a03_traits_vignette", "south_america",
    "a03_traits_boxed", "south_america",
    "a04_extract_raw", "west_north_america",
    "a05_references", "europe",
    "a06_age_uncertainty", "west_north_america",
    "a07_classification_table", NA_character_,
    "explore_vault", NA_character_
  )

assertthat::assert_that(
  name_workload %in% (data_workload_boxes |> dplyr::pull(workload)),
  msg = "Unknown workload."
)

name_box <-
  data_workload_boxes |>
  dplyr::filter(workload == name_workload) |>
  dplyr::pull(box_name)

list_box <-
  if (
    base::is.na(name_box)
  ) {
    NULL
  } else if (
    name_target != "v1"
  ) {
    purrr::chuck(list_settings_vaultkeepr, "subset_box")
  } else {
    purrr::chuck(list_settings_vaultkeepr, "boxes", name_box)
  }


#----------------------------------------------------------#
# 1. Workloads, from the vaultkeepr vignettes -----
#----------------------------------------------------------#

# `.x` is the read-only vault, `.y` the box
list_workloads <-
  list(
    # vignette a01: pollen of one genus in a box
    a01_taxa_distribution = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::select_dataset_by_type(
        sel_dataset_type = "fossil_pollen_archive"
      ) |>
      vaultkeepr::select_dataset_by_geo(
        long_lim = purrr::chuck(.y, "long_lim"),
        lat_lim = purrr::chuck(.y, "lat_lim"),
        verbose = FALSE
      ) |>
      vaultkeepr::get_samples() |>
      vaultkeepr::select_samples_by_age(
        age_lim = c(0, 8000),
        verbose = FALSE
      ) |>
      vaultkeepr::get_taxa(classify_to = "genus", verbose = FALSE) |>
      vaultkeepr::select_taxa_by_name(sel_taxa = "Betula") |>
      vaultkeepr::extract_data(verbose = FALSE),
    # vignette a01: the taxon names of the same selection
    a01_taxon_names = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::select_dataset_by_type(
        sel_dataset_type = "fossil_pollen_archive"
      ) |>
      vaultkeepr::select_dataset_by_geo(
        long_lim = purrr::chuck(.y, "long_lim"),
        lat_lim = purrr::chuck(.y, "lat_lim"),
        verbose = FALSE
      ) |>
      vaultkeepr::get_samples() |>
      vaultkeepr::select_samples_by_age(
        age_lim = c(0, 8000),
        verbose = FALSE
      ) |>
      vaultkeepr::get_taxa(classify_to = "genus", verbose = FALSE) |>
      vaultkeepr::get_taxon_names(),
    # vignette a02: plots with the nearest gridpoint climate
    a02_vegetation_climate = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::select_dataset_by_type(
        sel_dataset_type = c("vegetation_plot", "gridpoints")
      ) |>
      vaultkeepr::select_dataset_by_geo(
        long_lim = purrr::chuck(.y, "long_lim"),
        lat_lim = purrr::chuck(.y, "lat_lim"),
        verbose = FALSE
      ) |>
      vaultkeepr::get_samples() |>
      vaultkeepr::select_samples_by_age(
        age_lim = c(0, 0),
        sel_dataset_type = "vegetation_plot",
        verbose = FALSE
      ) |>
      vaultkeepr::get_abiotic_data(verbose = FALSE) |>
      vaultkeepr::select_abiotic_var_by_name(sel_var_name = "bio1") |>
      vaultkeepr::get_taxa(verbose = FALSE) |>
      vaultkeepr::extract_data(verbose = FALSE),
    # a02 with the mean of all linked gridpoints instead of the nearest
    a02_abiotic_mean = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::select_dataset_by_type(
        sel_dataset_type = c("vegetation_plot", "gridpoints")
      ) |>
      vaultkeepr::select_dataset_by_geo(
        long_lim = purrr::chuck(.y, "long_lim"),
        lat_lim = purrr::chuck(.y, "lat_lim"),
        verbose = FALSE
      ) |>
      vaultkeepr::get_samples() |>
      vaultkeepr::select_samples_by_age(
        age_lim = c(0, 0),
        sel_dataset_type = "vegetation_plot",
        verbose = FALSE
      ) |>
      vaultkeepr::get_abiotic_data(mode = "mean", verbose = FALSE) |>
      vaultkeepr::select_abiotic_var_by_name(sel_var_name = "bio1") |>
      vaultkeepr::get_taxa(verbose = FALSE) |>
      vaultkeepr::extract_data(verbose = FALSE),
    # vignette a03 as written: the box applies to the default dataset
    #   types, which leave out traits
    a03_traits_vignette = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::select_dataset_by_type(
        sel_dataset_type = c("fossil_pollen_archive", "traits")
      ) |>
      vaultkeepr::select_dataset_by_geo(
        long_lim = purrr::chuck(.y, "long_lim"),
        lat_lim = purrr::chuck(.y, "lat_lim"),
        verbose = FALSE
      ) |>
      vaultkeepr::get_samples() |>
      vaultkeepr::select_samples_by_age(
        age_lim = c(4000, 8000),
        verbose = FALSE
      ) |>
      vaultkeepr::get_taxa(classify_to = "genus", verbose = FALSE) |>
      vaultkeepr::get_traits(classify_to = "genus", verbose = FALSE) |>
      vaultkeepr::select_traits_by_domain_name(sel_domain = "Plant heigh") |>
      vaultkeepr::extract_data(verbose = FALSE),
    # a03 with the box applied to the traits too
    a03_traits_boxed = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::select_dataset_by_type(
        sel_dataset_type = c("fossil_pollen_archive", "traits")
      ) |>
      vaultkeepr::select_dataset_by_geo(
        long_lim = purrr::chuck(.y, "long_lim"),
        lat_lim = purrr::chuck(.y, "lat_lim"),
        sel_dataset_type = c("fossil_pollen_archive", "traits"),
        verbose = FALSE
      ) |>
      vaultkeepr::get_samples() |>
      vaultkeepr::select_samples_by_age(
        age_lim = c(4000, 8000),
        verbose = FALSE
      ) |>
      vaultkeepr::get_taxa(classify_to = "genus", verbose = FALSE) |>
      vaultkeepr::get_traits(classify_to = "genus", verbose = FALSE) |>
      vaultkeepr::select_traits_by_domain_name(sel_domain = "Plant heigh") |>
      vaultkeepr::extract_data(verbose = FALSE),
    # vignette a04: everything in a box, as flat rows; no dataset type is
    #   selected, so the default box types apply
    a04_extract_raw = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::select_dataset_by_geo(
        long_lim = purrr::chuck(.y, "long_lim"),
        lat_lim = purrr::chuck(.y, "lat_lim"),
        verbose = FALSE
      ) |>
      vaultkeepr::get_samples() |>
      vaultkeepr::get_taxa(verbose = FALSE) |>
      vaultkeepr::extract_data(return_raw_data = TRUE, verbose = FALSE),
    # vignette a05: the references of a selection
    a05_references = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::select_dataset_by_type(
        sel_dataset_type = c("vegetation_plot", "gridpoints")
      ) |>
      vaultkeepr::select_dataset_by_geo(
        long_lim = purrr::chuck(.y, "long_lim"),
        lat_lim = purrr::chuck(.y, "lat_lim"),
        verbose = FALSE
      ) |>
      vaultkeepr::get_samples() |>
      vaultkeepr::get_taxa(verbose = FALSE) |>
      vaultkeepr::get_abiotic_data(verbose = FALSE) |>
      vaultkeepr::get_references(verbose = FALSE),
    # vignette a06: age-depth uncertainty of pollen samples
    a06_age_uncertainty = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::select_dataset_by_type(
        sel_dataset_type = "fossil_pollen_archive"
      ) |>
      vaultkeepr::select_dataset_by_geo(
        long_lim = purrr::chuck(.y, "long_lim"),
        lat_lim = purrr::chuck(.y, "lat_lim"),
        verbose = FALSE
      ) |>
      vaultkeepr::get_samples() |>
      vaultkeepr::select_samples_by_age(
        age_lim = c(0, 8000),
        verbose = FALSE
      ) |>
      vaultkeepr::get_age_uncertainty(),
    # vignette a07: the classification table of the whole database
    a07_classification_table = ~ .x |>
      vaultkeepr::get_datasets() |>
      vaultkeepr::get_samples() |>
      vaultkeepr::get_taxa(classify_to = "original", verbose = FALSE) |>
      vaultkeepr::get_classification_table(),
    explore_vault = ~ vaultkeepr::explore_vault(.x)
  )


#----------------------------------------------------------#
# 2. Load vaultkeepr and open the database read-only -----
#----------------------------------------------------------#

pkgload::load_all(
  path = path_vaultkeepr,
  export_all = FALSE,
  helpers = FALSE,
  attach_testthat = FALSE,
  quiet = TRUE
)

vec_vaultkeepr_functions <-
  base::ls(base::asNamespace("vaultkeepr"))

# The pipeline steps; the native pipe nests them, so the innermost
#   exported function on the stack is the step that sent a statement
vec_vaultkeepr_exports <-
  base::getNamespaceExports("vaultkeepr")

con_db <-
  DBI::dbConnect(
    drv = RSQLite::SQLite(),
    dbname = path_db,
    flags = RSQLite::SQLITE_RO
  )

# The structure open_vault() returns, around a read-only connection
vault_ro <-
  base::structure(
    list(
      data = tibble::tibble(),
      db_con = con_db
    ),
    class = c("list", "vault_pipe")
  )


#----------------------------------------------------------#
# 3. Log every statement -----
#----------------------------------------------------------#

# Each tracer appends one JSON line; it runs inside `local()`, so it adds
#   nothing to the traced frame
list_tracers <-
  purrr::map(
    .x = c(create = "create", release = "release"),
    .f = ~ base::bquote(
      base::local({
        env_traced <-
          base::parent.env(base::environment())

        vec_stack <-
          base::sys.calls() |>
          purrr::map_chr(
            .f = ~ base::deparse(.x[[1L]], nlines = 1L) |>
              stringr::str_remove("^.*::")
          ) |>
          purrr::keep(.p = ~ .x %in% vec_vaultkeepr_functions)

        base::cat(
          jsonlite::toJSON(
            list(
              event = .(.x),
              epoch = base::sprintf(
                "%.6f", base::as.numeric(base::Sys.time())
              ),
              fn_step = purrr::keep(
                .x = vec_stack,
                .p = ~ .x %in% vec_vaultkeepr_exports
              ) |>
                dplyr::last(default = NA_character_),
              fn_inner = dplyr::last(vec_stack, default = NA_character_),
              sql = if (
                .(.x) == "create"
              ) {
                base::get("sql", envir = env_traced)
              } else {
                NA_character_
              }
            ),
            auto_unbox = TRUE,
            na = "null"
          ),
          "\n",
          sep = "",
          file = .(path_log),
          append = TRUE
        )
      })
    )
  )

base::trace(
  what = "result_create",
  tracer = purrr::chuck(list_tracers, "create"),
  print = FALSE,
  where = base::asNamespace("RSQLite")
)

base::trace(
  what = "result_release",
  tracer = purrr::chuck(list_tracers, "release"),
  print = FALSE,
  where = base::asNamespace("RSQLite")
)


#----------------------------------------------------------#
# 4. Run the workload -----
#----------------------------------------------------------#

data_memory_start <-
  base::gc(reset = TRUE)

time_start <-
  base::Sys.time()

res_workload <-
  tryCatch(
    expr = {
      purrr::safely(
        .f = rlang::as_function(purrr::chuck(list_workloads, name_workload))
      )(.x = vault_ro, .y = list_box)
    },
    finally = {
      base::untrace(
        what = "result_create",
        where = base::asNamespace("RSQLite")
      )
      base::untrace(
        what = "result_release",
        where = base::asNamespace("RSQLite")
      )
      DBI::dbDisconnect(con_db)
    }
  )

seconds_workload <-
  base::difftime(base::Sys.time(), time_start, units = "secs") |>
  base::as.numeric()

data_memory_end <-
  base::gc()

data_result <-
  purrr::chuck(res_workload, "result")

base::cat(
  jsonlite::toJSON(
    list(
      event = "summary",
      target = name_target,
      workload = name_workload,
      repetition = n_repetition,
      box_name = name_box,
      seconds = seconds_workload,
      n_rows = if (
        base::is.data.frame(data_result)
      ) {
        base::nrow(data_result)
      } else {
        NA_integer_
      },
      result_mb = base::as.numeric(utils::object.size(data_result)) / 2^20,
      # The last column of `gc()` is the maximum used, in Mb
      max_memory_mb = data_memory_end[, base::ncol(data_memory_end)] |>
        base::sum(),
      # cli errors keep their text in the condition message, not `$message`
      error = purrr::possibly(
        .f = ~ base::conditionMessage(.x) |>
          stringr::str_squish() |>
          stringr::str_trunc(width = 300L),
        otherwise = NA_character_
      )(purrr::pluck(res_workload, "error"))
    ),
    auto_unbox = TRUE,
    na = "null"
  ),
  "\n",
  sep = "",
  file = path_log,
  append = TRUE
)
