#----------------------------------------------------------#
#
#
#                       VegVault
#
#        Read the v1.1.0 gridpoint inputs with legacy R
#         - called by 07_prepare_profiling_inputs.R only
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# The v1.1.0 abiotic artefacts are legacy `qs` files, which R 4.6 cannot
#   read. 07_prepare_profiling_inputs.R runs this script with R 4.5.1 and
#   `--vanilla` (no project profile, so no renv) and the R 4.5 library of
#   the trait producer, which holds `qs`. The artefacts are only read. The
#   gridpoint coordinates and ages are derived exactly as in
#   R/02_Main_analyses/06_Create_gridpoints.R and saved, with the unchanged
#   current-climate artefact, as `.rds` files.
#
# Arguments: library folder, artefact folder, output folder, the three
#   paleoclimate files, the current-climate file.


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

vec_args <-
  base::commandArgs(trailingOnly = TRUE)

base::stopifnot(
  "Seven arguments are expected" = base::length(vec_args) == 7L
)

# The library holding `qs` goes first; base packages stay available
base::.libPaths(new = vec_args[1L])

path_artefacts <-
  purrr::chuck(vec_args, 2L)

path_output <-
  purrr::chuck(vec_args, 3L)

vec_paleo_files <-
  vec_args[4:6]

file_neo <-
  purrr::chuck(vec_args, 7L)


#----------------------------------------------------------#
# 1. Read the artefacts -----
#----------------------------------------------------------#

data_paleo_climate <-
  vec_paleo_files |>
  purrr::map(
    .f = ~ qs::qread(file = base::file.path(path_artefacts, .x))
  ) |>
  dplyr::bind_rows() |>
  dplyr::select(-"value")

data_neo_climate <-
  qs::qread(
    file = base::file.path(path_artefacts, file_neo)
  )


#----------------------------------------------------------#
# 2. Derive gridpoint ages and coordinates as in v1 -----
#----------------------------------------------------------#

vec_age <-
  data_paleo_climate |>
  dplyr::distinct(time_id) |>
  tidyr::drop_na("time_id") |>
  dplyr::mutate(
    age = (-base::as.numeric(time_id) * 100) + 2000
  ) |>
  dplyr::arrange(age) |>
  purrr::chuck("age")

# `round()` on the whole table, as in v1
data_paleo_coord <-
  data_paleo_climate |>
  dplyr::select(-"time_id") |>
  base::round(digits = 2) |>
  dplyr::distinct(long, lat) |>
  tidyr::drop_na()

data_neo_coords <-
  data_neo_climate |>
  dplyr::select(-c("value", "var_name")) |>
  base::round(digits = 2) |>
  dplyr::distinct(long, lat) |>
  tidyr::drop_na()

# v1 leaves the soil coordinates out (commented out in stage 06)
data_coord <-
  data_paleo_coord |>
  dplyr::bind_rows(data_neo_coords) |>
  dplyr::distinct(long, lat) |>
  tidyr::drop_na() |>
  tibble::as_tibble()


#----------------------------------------------------------#
# 3. Save -----
#----------------------------------------------------------#

list_outputs <-
  list(
    gridpoint_ages = vec_age,
    gridpoint_coords_global = data_coord,
    chelsa_neo_bio01_global = data_neo_climate
  )

# Each file is written under a temporary name and renamed when complete
purrr::iwalk(
  .x = list_outputs,
  .f = ~ {
    path_file <-
      base::file.path(path_output, stringr::str_c(.y, ".rds"))

    path_partial <-
      stringr::str_c(path_file, ".partial")

    base::saveRDS(object = .x, file = path_partial)

    base::stopifnot(
      "Renaming the saved file failed" =
        base::file.rename(from = path_partial, to = path_file)
    )
  }
)

base::cat(
  "paleo rows:", base::nrow(data_paleo_climate),
  "| ages:", base::length(vec_age),
  "| paleo cells:", base::nrow(data_paleo_coord),
  "| current cells:", base::nrow(data_neo_coords),
  "| gridpoint cells:", base::nrow(data_coord),
  "\n"
)
