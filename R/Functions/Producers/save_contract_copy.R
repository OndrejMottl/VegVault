#' @title Save a copy of the VegVault contracts into a producer checkout
#' @description
#' Copy the contract functions and the producer's own contracts from a
#' VegVault checkout into a producer checkout, at the same relative paths,
#' and write the record `Data/Contracts/contract_copy.yml` with the
#' VegVault commit and the fingerprint of every copied file. The producer
#' then validates its exports with its own copy, wherever VegVault is
#' checked out, and `validate_contract_copy()` detects a changed or
#' outdated copy.
#' @param path_producer
#' Character scalar. Root folder of the producer checkout that receives
#' the copy.
#' @param repository
#' Character scalar. The producer repository as the contracts name it in
#' `producer: repository`, for example
#' `"OndrejMottl/VegVault-Vegetation_data"`.
#' @param ref_base
#' Character scalar. The git reference that must contain the VegVault
#' commit, normally the shared release branch, for example
#' `"origin/2.0.0"`.
#' @param path_vegvault
#' Character scalar. Root folder of the VegVault checkout to copy from.
#' Defaults to the project root.
#' @param verbose
#' Logical. If `TRUE` (default), a summary is printed to the console via
#' `cli`.
#' @return
#' Invisibly, the new record as returned by `load_contract_copy_record()`.
#' @details
#' The files are those of `select_contract_copy_files()`: every `.R` file
#' of `R/Functions/Contracts/` and the producer's contracts that are not
#' retired. Nothing is written, and the function aborts, when:
#' - `R/Functions/Contracts/` or `Data/Contracts/` of the VegVault checkout
#'   has uncommitted changes or untracked files, because the record would
#'   cite a commit that does not hold the copied text;
#' - the checked-out VegVault commit is not contained in `ref_base`,
#'   because a commit that exists only on a feature branch is lost after a
#'   squash merge;
#' - a selected contract fails `load_producer_contract()`;
#' - the producer already holds a copy for another repository;
#' - the producer holds a `.R` file in `R/Functions/Contracts/` or a `.yml`
#'   file in `Data/Contracts/` that an earlier copy did not write.
#' The files listed by an earlier record are deleted before copying, so a
#' file that VegVault no longer has disappears from the copy. Files are
#' copied byte for byte. The function never commits; the producer commits
#' the copy and the record.
#' @seealso [select_contract_copy_files()], [validate_contract_copy()]
#' @examples
#' \dontrun{
#' save_contract_copy(
#'   path_producer = "../VegVault-Vegetation_data",
#'   repository = "OndrejMottl/VegVault-Vegetation_data",
#'   ref_base = "origin/2.0.0"
#' )
#' }
save_contract_copy <- function(
  path_producer,
  repository,
  ref_base,
  path_vegvault = here::here(),
  verbose = TRUE
) {
  assertthat::assert_that(
    base::is.character(path_producer),
    base::length(path_producer) == 1L,
    !base::is.na(path_producer),
    base::dir.exists(path_producer),
    msg = "`path_producer` must be the path of an existing folder."
  )

  assertthat::assert_that(
    base::is.character(repository),
    base::length(repository) == 1L,
    !base::is.na(repository),
    base::nzchar(repository),
    msg = "`repository` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.character(ref_base),
    base::length(ref_base) == 1L,
    !base::is.na(ref_base),
    base::nzchar(ref_base),
    msg = "`ref_base` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.character(path_vegvault),
    base::length(path_vegvault) == 1L,
    !base::is.na(path_vegvault),
    base::dir.exists(path_vegvault),
    msg = "`path_vegvault` must be the path of an existing folder."
  )

  assertthat::assert_that(
    base::normalizePath(path_producer, winslash = "/") !=
      base::normalizePath(path_vegvault, winslash = "/"),
    msg = "`path_producer` must not be the VegVault checkout itself."
  )

  assertthat::assert_that(
    base::is.logical(verbose),
    base::length(verbose) == 1L,
    !base::is.na(verbose),
    msg = "`verbose` must be TRUE or FALSE."
  )

  #--------------------------------------------------#
  ## Source commit -----
  #--------------------------------------------------#

  vec_folders_copied <-
    c("R/Functions/Contracts", "Data/Contracts")

  flag_source_clean <-
    is_git_clean(
      path_project = path_vegvault,
      vec_paths = vec_folders_copied
    )

  if (
    !flag_source_clean
  ) {
    cli::cli_abort(
      c(
        "The VegVault folders {.path R/Functions/Contracts} and
        {.path Data/Contracts} have uncommitted changes or untracked
        files.",
        "i" = "The record would cite a commit that does not hold the copied
        text. Commit or remove the changes in {.path {path_vegvault}}
        first."
      )
    )
  }

  flag_commit_in_ref <-
    is_git_commit_in_ref(
      path_project = path_vegvault,
      ref_base = ref_base
    )

  if (
    !flag_commit_in_ref
  ) {
    cli::cli_abort(
      c(
        "The checked-out VegVault commit is not contained in
        {.val {ref_base}}.",
        "i" = "Copy from a commit of the shared branch: a commit that exists
        only on a feature branch is lost after a squash merge. Run
        {.code git fetch} first if {.val {ref_base}} has moved."
      )
    )
  }

  vegvault_commit <-
    load_git_commit(path_project = path_vegvault)

  #--------------------------------------------------#
  ## Files to copy -----
  #--------------------------------------------------#

  data_files_selected <-
    select_contract_copy_files(
      path_vegvault = path_vegvault,
      repository = repository
    )

  # Every copied contract must pass the current contract format
  data_files_selected |>
    dplyr::filter(!base::is.na(contract_id)) |>
    dplyr::pull(path) |>
    purrr::walk(
      .f = ~ load_producer_contract(
        path_contract = base::file.path(path_vegvault, .x)
      )
    )

  #--------------------------------------------------#
  ## Files of an earlier copy -----
  #--------------------------------------------------#

  path_record <-
    base::file.path(path_producer, "Data", "Contracts", "contract_copy.yml")

  list_record_old <-
    if (
      base::file.exists(path_record)
    ) {
      load_contract_copy_record(path_producer = path_producer)
    } else {
      NULL
    }

  vec_paths_old <-
    if (
      base::is.null(list_record_old)
    ) {
      base::character(0)
    } else {
      list_record_old |>
        purrr::chuck("data_files") |>
        dplyr::pull(path)
    }

  if (
    !base::is.null(list_record_old) &&
      purrr::chuck(list_record_old, "producer_repository") != repository
  ) {
    repository_old <-
      purrr::chuck(list_record_old, "producer_repository")

    cli::cli_abort(
      c(
        "{.path {path_producer}} already holds a contract copy for
        {.val {repository_old}}, not {.val {repository}}.",
        "i" = "Check `path_producer` and `repository`."
      )
    )
  }

  vec_paths_existing <-
    c(
      stringr::str_c(
        "R/Functions/Contracts/",
        base::list.files(
          path = base::file.path(path_producer, "R", "Functions", "Contracts"),
          pattern = "[.]R$"
        )
      ),
      stringr::str_c(
        "Data/Contracts/",
        base::list.files(
          path = base::file.path(path_producer, "Data", "Contracts"),
          pattern = "[.]yml$"
        )
      )
    ) |>
    base::setdiff("Data/Contracts/contract_copy.yml")

  vec_paths_unowned <-
    base::setdiff(vec_paths_existing, vec_paths_old)

  if (
    base::length(vec_paths_unowned) > 0L
  ) {
    cli::cli_abort(
      c(
        "{.path {path_producer}} holds files in the copy folders that no
        earlier copy wrote.",
        "x" = "{.file {vec_paths_unowned}}",
        "i" = "Move them out of {.path R/Functions/Contracts} and
        {.path Data/Contracts}; those folders hold only the copy."
      )
    )
  }

  #--------------------------------------------------#
  ## Copy -----
  #--------------------------------------------------#

  vec_is_old_present <-
    base::file.exists(base::file.path(path_producer, vec_paths_old))

  base::file.remove(
    base::file.path(path_producer, vec_paths_old[vec_is_old_present])
  )

  vec_paths_copy <-
    dplyr::pull(data_files_selected, path)

  vec_dirs_target <-
    base::file.path(path_producer, vec_paths_copy) |>
    base::dirname() |>
    base::unique()

  purrr::walk(
    .x = vec_dirs_target,
    .f = ~ base::dir.create(path = .x, recursive = TRUE, showWarnings = FALSE)
  )

  vec_is_copied <-
    base::file.copy(
      from = base::file.path(path_vegvault, vec_paths_copy),
      to = base::file.path(path_producer, vec_paths_copy),
      overwrite = FALSE
    )

  if (
    !base::all(vec_is_copied)
  ) {
    cli::cli_abort(
      c(
        "Some files could not be copied into {.path {path_producer}}.",
        "x" = "{.file {vec_paths_copy[!vec_is_copied]}}"
      )
    )
  }

  #--------------------------------------------------#
  ## Record -----
  #--------------------------------------------------#

  data_files_record <-
    dplyr::select(
      data_files_selected,
      "path", "sha256", "contract_id", "contract_version"
    )

  # Function files have no contract fields, so their NA values are dropped.
  #   Indexed rather than pmap() with ..1: targets warns on ..1 when it
  #   scans the functions a pipeline loads
  list_files_record <-
    purrr::map(
      .x = base::seq_len(base::nrow(data_files_record)),
      .f = ~ {
        index_file <- .x

        data_files_record[index_file, ] |>
          base::as.list() |>
          purrr::discard(.p = ~ base::is.na(.x))
      }
    )

  text_record <-
    c(
      "# Copy of the VegVault producer contracts, written by",
      "#   save_contract_copy(). Do not edit the copied files or this record;",
      "#   make the copy again from a VegVault checkout instead.",
      yaml::as.yaml(
        x = base::list(
          vegvault_commit = vegvault_commit,
          producer_repository = repository,
          files = list_files_record
        )
      ) |>
        stringr::str_remove(pattern = "\n$")
    )

  base::writeLines(text = text_record, con = path_record)

  res <-
    load_contract_copy_record(path_producer = path_producer)

  if (
    base::isTRUE(verbose)
  ) {
    n_files <-
      base::length(vec_paths_copy)

    commit_short <-
      stringr::str_sub(vegvault_commit, 1L, 7L)

    cli::cli_inform(
      c(
        "v" = "Copied {n_files} files from VegVault commit {commit_short}
        into {.path {path_producer}}.",
        "i" = "Commit the copy and {.file Data/Contracts/contract_copy.yml}
        in the producer repository."
      )
    )
  }

  return(invisible(res))
}
