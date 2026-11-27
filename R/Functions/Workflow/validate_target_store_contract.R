#' @title Validate a target-store contract
#' @description
#' Check that an upstream target store exists, contains every required
#' public target as a completed target, and that its latest run finished:
#' no target errored, was canceled or was left running, and every required
#' public target was built or found up to date in that run.
#' @param store
#' Character scalar upstream target-store path.
#' @param target_names
#' Character vector of required public target names.
#' @param runner
#' Character scalar runner script that builds the upstream store. It is
#' named in the error message so the user knows what to run first.
#' @return
#' Invisibly returns a tibble with the `name` and `data` (hash) metadata of
#' the required targets.
#' @details
#' `{targets}` keeps the last good value of a target whose rebuild failed,
#' and a run that stops early leaves the targets it did not reach at their
#' old values. The run check reads `targets::tar_progress()` of the store,
#' which covers only its latest run, so a downstream pipeline never imports
#' values from a run that failed, was interrupted, or did not reach the
#' public targets (for example a run of selected targets only). Each check
#' aborts with a message that names `runner`.
#' @examples
#' \dontrun{
#' validate_target_store_contract(
#'   store = store_data_preparation,
#'   target_names = "data_prepared",
#'   runner = "R/Analyses/01_Data_preparation/00_run.R"
#' )
#' }
validate_target_store_contract <- function(store,
                                           target_names,
                                           runner) {
  assertthat::assert_that(
    base::is.character(store),
    base::length(store) == 1L,
    base::is.character(target_names),
    base::length(target_names) > 0L,
    base::all(!base::is.na(target_names)),
    base::all(base::nzchar(target_names)),
    base::is.character(runner),
    base::length(runner) == 1L,
    !base::is.na(runner),
    base::nzchar(runner),
    msg = "Target-store contract arguments are invalid."
  )

  if (
    isFALSE(base::dir.exists(store))
  ) {
    cli::cli_abort(
      c(
        "The required upstream target store does not exist:",
        "x" = "{.path {store}}",
        "i" = "Run {.path {runner}} first."
      )
    )
  }

  data_meta <-
    targets::tar_meta(
      fields = c("name", "data"),
      complete_only = TRUE,
      store = store
    ) |>
    dplyr::filter(.data[["name"]] %in% target_names)

  vec_missing_targets <-
    base::setdiff(
      target_names,
      dplyr::pull(data_meta, "name")
    )

  if (
    base::length(vec_missing_targets) > 0L
  ) {
    cli::cli_abort(
      c(
        "The upstream store is missing public targets:",
        "x" = "{.val {vec_missing_targets}}",
        "i" = "Run {.path {runner}} first."
      )
    )
  }

  # Progress of the latest run only; empty when the store has none
  data_progress <-
    targets::tar_progress(store = store)

  vec_targets_unfinished <-
    data_progress |>
    dplyr::filter(
      .data[["progress"]] %in% c("errored", "canceled", "dispatched")
    ) |>
    dplyr::pull("name")

  if (
    base::length(vec_targets_unfinished) > 0L
  ) {
    cli::cli_abort(
      c(
        "The latest run of the upstream store did not finish, so its values
          may be stale:",
        "x" = "Errored, canceled or left running: {.val
          {vec_targets_unfinished}}",
        "i" = "Fix the cause and run {.path {runner}} again."
      )
    )
  }

  vec_targets_not_run <-
    base::setdiff(
      target_names,
      data_progress |>
        dplyr::filter(.data[["progress"]] %in% c("completed", "skipped")) |>
        dplyr::pull("name")
    )

  if (
    base::length(vec_targets_not_run) > 0L
  ) {
    cli::cli_abort(
      c(
        "Public targets were not built or checked in the latest run of the
          upstream store:",
        "x" = "{.val {vec_targets_not_run}}",
        "i" = "Run {.path {runner}} in full first."
      )
    )
  }

  res_meta <-
    data_meta |>
    dplyr::select(dplyr::all_of(c("name", "data")))

  return(invisible(res_meta))
}
