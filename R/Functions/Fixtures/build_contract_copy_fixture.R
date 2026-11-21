#' @title Build a VegVault checkout and a producer folder for copy tests
#' @description
#' Create, inside `dir_root`, a small git repository `vegvault` laid out
#' like a VegVault checkout, with one commit on the branch `main`, and an
#' empty folder `producer`, so that copying the contracts into a producer
#' and checking the copy can be tested without the real repositories.
#' @param dir_root
#' Character scalar. Path of an existing, empty folder.
#' @param path_contracts
#' Character scalar. Folder holding the real contract files
#' `splot_plots.yml`, `bien_plots.yml` and `hwsd_soil.yml`. Defaults to
#' the project's `Data/Contracts`.
#' @return
#' A list with `path_vegvault` and `path_producer`, the paths of the two
#' folders.
#' @details
#' The repository `vegvault` holds:
#' - `R/Functions/Contracts/load_example_contract.R` and
#'   `R/Functions/Contracts/validate_example_artefact.R`, each defining a
#'   trivial function;
#' - `Data/Contracts/splot_plots.yml` and `Data/Contracts/bien_plots.yml`
#'   (producer `OndrejMottl/VegVault-Vegetation_data`) and
#'   `Data/Contracts/hwsd_soil.yml` (`OndrejMottl/VegVault-abiotic_data`),
#'   with the text of the real contracts;
#' - `Data/Contracts/old_plots.yml`, a retired copy of `splot_plots` for
#'   the vegetation producer;
#' - `Data/Contracts/README.md` and
#'   `Data/Contracts/fixtures/valid/splot_plots/example.txt`, which a copy
#'   leaves out.
#' Every file is written with LF line endings and committed without
#' line-ending conversion through `run_git_fixture_command()`. Aborts when
#' `dir_root` is not empty or a real contract file is missing. Calls the
#' `git` executable.
#' @examples
#' \dontrun{
#' list_paths <-
#'   build_contract_copy_fixture(dir_root = withr::local_tempdir())
#' }
build_contract_copy_fixture <- function(
  dir_root,
  path_contracts = here::here("Data", "Contracts")
) {
  assertthat::assert_that(
    base::is.character(dir_root),
    base::length(dir_root) == 1L,
    !base::is.na(dir_root),
    base::dir.exists(dir_root),
    msg = "`dir_root` must be the path of an existing, empty folder."
  )

  assertthat::assert_that(
    base::length(
      base::list.files(path = dir_root, all.files = TRUE, no.. = TRUE)
    ) == 0L,
    msg = "`dir_root` must be the path of an existing, empty folder."
  )

  assertthat::assert_that(
    base::is.character(path_contracts),
    base::length(path_contracts) == 1L,
    !base::is.na(path_contracts),
    base::dir.exists(path_contracts),
    msg = "`path_contracts` must be the path of an existing folder."
  )

  vec_contracts_real <-
    c("splot_plots", "bien_plots", "hwsd_soil")

  vec_paths_real <-
    base::file.path(
      path_contracts,
      stringr::str_c(vec_contracts_real, ".yml")
    ) |>
    rlang::set_names(vec_contracts_real)

  vec_paths_missing <-
    vec_paths_real[!base::file.exists(vec_paths_real)]

  if (
    base::length(vec_paths_missing) > 0L
  ) {
    cli::cli_abort(
      c(
        "Real contract files are missing from {.path {path_contracts}}.",
        "x" = "{.file {base::basename(vec_paths_missing)}}"
      )
    )
  }

  list_text_real <-
    purrr::map(
      .x = vec_paths_real,
      .f = ~ base::readLines(con = .x, warn = FALSE, encoding = "UTF-8")
    )

  list_contract_retired <-
    yaml::read_yaml(file = purrr::chuck(vec_paths_real, "splot_plots")) |>
    purrr::list_modify(
      contract_id = "old_plots",
      status = "retired",
      status_note = "Replaced by splot_plots; kept for the copy tests."
    )

  text_contract_retired <-
    yaml::as.yaml(x = list_contract_retired) |>
    stringr::str_remove(pattern = "\n$")

  list_files <-
    base::list(
      "R/Functions/Contracts/load_example_contract.R" = c(
        "load_example_contract <- function() {",
        "  res <- \"contract\"",
        "",
        "  return(res)",
        "}"
      ),
      "R/Functions/Contracts/validate_example_artefact.R" = c(
        "validate_example_artefact <- function() {",
        "  res <- TRUE",
        "",
        "  return(res)",
        "}"
      ),
      "Data/Contracts/splot_plots.yml" = purrr::chuck(
        list_text_real,
        "splot_plots"
      ),
      "Data/Contracts/bien_plots.yml" = purrr::chuck(
        list_text_real,
        "bien_plots"
      ),
      "Data/Contracts/hwsd_soil.yml" = purrr::chuck(
        list_text_real,
        "hwsd_soil"
      ),
      "Data/Contracts/old_plots.yml" = text_contract_retired,
      "Data/Contracts/README.md" = "# Example contracts",
      "Data/Contracts/fixtures/valid/splot_plots/example.txt" = "example"
    )

  path_vegvault <-
    base::file.path(dir_root, "vegvault")

  path_producer <-
    base::file.path(dir_root, "producer")

  base::dir.create(path_vegvault)

  base::dir.create(path_producer)

  # Written as bytes, so every line ends with LF on any system
  purrr::iwalk(
    .x = list_files,
    .f = ~ {
      path_file <-
        base::file.path(path_vegvault, .y)

      base::dir.create(
        path = base::dirname(path_file),
        recursive = TRUE,
        showWarnings = FALSE
      )

      base::writeBin(
        object = base::charToRaw(
          base::enc2utf8(stringr::str_c(stringr::str_flatten(.x, "\n"), "\n"))
        ),
        con = path_file
      )
    }
  )

  run_git_fixture_command(
    path_repo = path_vegvault,
    vec_args = c("init", "--quiet", "--initial-branch=main")
  )

  run_git_fixture_command(
    path_repo = path_vegvault,
    vec_args = c("add", "--all")
  )

  run_git_fixture_command(
    path_repo = path_vegvault,
    vec_args = c("commit", "--quiet", "-m", "contracts")
  )

  res <-
    base::list(
      path_vegvault = path_vegvault,
      path_producer = path_producer
    )

  return(res)
}
