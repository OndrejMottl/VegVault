#----------------------------------------------------------#
#
#
#                       VegVault
#
#              Build producer contract fixtures
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#

# Write the synthetic fixtures of every producer artefact contract in
#   Data/Contracts/ to Data/Contracts/fixtures/valid/<contract_id>/ and
#   Data/Contracts/fixtures/broken/<contract_id>/. The fixtures are built by
#   the build_<contract_id>_fixture() functions from invented values; no
#   real data is read. The output is deterministic: rerunning the script
#   gives identical objects and file names.
# The script sources only the contract functions, not R/00_Config_file.R,
#   so it needs no database path and installs nothing. Run it from the
#   repository root with:
#   Rscript R/Contracts/build_contract_fixtures.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

vec_function_files <-
  base::list.files(
    path = here::here("R", "Functions", "Contracts"),
    pattern = "[.]R$",
    full.names = TRUE
  )

purrr::walk(
  .x = vec_function_files,
  .f = ~ base::source(file = .x, encoding = "UTF-8")
)

# Existing fixtures are kept unless this is TRUE. When TRUE, the fixture
#   files of every contract are deleted and written again; deleting first
#   matters because a changed fixture gets a new hash in its file name
flag_rewrite <- FALSE

date_fixture <- "2000-01-01"

path_fixtures <-
  here::here("Data", "Contracts", "fixtures")


#----------------------------------------------------------#
# 1. Build fixtures -----
#----------------------------------------------------------#

vec_contract_paths <-
  base::list.files(
    path = here::here("Data", "Contracts"),
    pattern = "[.]yml$",
    full.names = TRUE
  )

list_contracts <-
  purrr::map(
    .x = vec_contract_paths,
    .f = ~ load_producer_contract(path_contract = .x)
  )

vec_contract_ids <-
  purrr::map_chr(
    .x = list_contracts,
    .f = ~ purrr::chuck(.x, "contract_id")
  )

# Every contract needs a builder named after it
vec_builders <-
  stringr::str_c("build_", vec_contract_ids, "_fixture")

vec_builders_missing <-
  vec_builders[!purrr::map_lgl(vec_builders, base::exists)]

if (
  base::length(vec_builders_missing) > 0L
) {
  cli::cli_abort(
    "No fixture builder for: {.fn {vec_builders_missing}}."
  )
}

data_fixtures <-
  tidyr::expand_grid(
    index_contract = base::seq_along(list_contracts),
    variant = c("valid", "broken")
  ) |>
  dplyr::mutate(
    contract_id = vec_contract_ids[.data[["index_contract"]]],
    dir_output = base::file.path(
      path_fixtures,
      .data[["variant"]],
      .data[["contract_id"]]
    ),
    list_fixture = purrr::map2(
      .x = .data[["index_contract"]],
      .y = .data[["variant"]],
      .f = ~ rlang::exec(
        .fn = vec_builders[.x],
        contract = list_contracts[[.x]],
        date_file = date_fixture,
        flag_broken = .y == "broken"
      )
    )
  )


#----------------------------------------------------------#
# 2. Check fixtures against their contracts -----
#----------------------------------------------------------#

# A valid fixture must satisfy its contract and a broken one must not,
#   before anything is written
data_checks <-
  data_fixtures |>
  dplyr::mutate(
    n_findings = purrr::map2_int(
      .x = .data[["list_fixture"]],
      .y = .data[["index_contract"]],
      .f = ~ base::nrow(
        diagnose_producer_artefact(
          data_artefact = .x,
          contract = list_contracts[[.y]]
        )
      )
    ),
    is_expected = dplyr::if_else(
      .data[["variant"]] == "valid",
      .data[["n_findings"]] == 0L,
      .data[["n_findings"]] > 0L
    )
  )

data_unexpected <-
  dplyr::filter(data_checks, !.data[["is_expected"]])

if (
  base::nrow(data_unexpected) > 0L
) {
  cli::cli_abort(
    c(
      "Fixtures do not behave as expected:",
      "x" = "{dplyr::pull(data_unexpected, 'variant')} fixture of
      {dplyr::pull(data_unexpected, 'contract_id')}"
    )
  )
}


#----------------------------------------------------------#
# 3. Save fixtures -----
#----------------------------------------------------------#

purrr::walk(
  .x = base::seq_len(base::nrow(data_fixtures)),
  .f = ~ {
    dir_output <-
      dplyr::pull(data_fixtures, "dir_output")[.x]

    vec_existing <-
      base::list.files(
        path = dir_output,
        pattern = "[.](qs|rds)$",
        full.names = TRUE
      )

    if (
      base::length(vec_existing) > 0L && base::isFALSE(flag_rewrite)
    ) {
      cli::cli_inform(
        "Kept existing fixtures in {.path {dir_output}};
        set {.code flag_rewrite} to TRUE to rebuild them."
      )

      return(base::invisible(NULL))
    }

    base::unlink(vec_existing)

    base::dir.create(dir_output, recursive = TRUE, showWarnings = FALSE)

    save_producer_fixture(
      list_fixture = dplyr::pull(data_fixtures, "list_fixture")[[.x]],
      dir_output = dir_output
    )
  }
)

cli::cli_alert_success(
  "Fixtures of {base::length(list_contracts)} contracts are in
  {.path {path_fixtures}}."
)
