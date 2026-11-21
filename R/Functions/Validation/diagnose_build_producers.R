#' @title Diagnose the producer rows of a database build
#' @description
#' Compare the `BuildProducers` rows of the version being built with the
#' producer pins of the build manifest, read-only.
#' @param path_database
#' Character scalar. Path of the database file.
#' @param list_build_manifest
#' Named list. The build manifest of the database, as returned by
#' `load_build_manifest()`.
#' @return
#' A tibble in the format of `build_check_result()`, check
#' `build_producers`: one `pass` row with scope `BuildProducers` when the
#' rows match the pins, otherwise one `fail` row per artefact that is
#' missing, not pinned, or recorded with another tag, or that lacks a tag
#' or commit in a release build.
#' @details
#' The rows checked are those whose `version_id` is the highest `id` of
#' `version_control`. Each pin needs exactly one row with `producer` equal
#' to its `artefact_id` and the same `tag`; a `dev` pin has no tag, which
#' is stored as missing. In a build with the `release` profile every row
#' also needs a tag and a 40-character commit hash in `commit_sha`. Opens
#' the database read-only. Aborts only when the database is not the one of
#' the manifest.
#' @examples
#' \dontrun{
#' diagnose_build_producers(
#'   path_database = path_database,
#'   list_build_manifest = list_build_manifest
#' )
#' }
diagnose_build_producers <- function(
  path_database,
  list_build_manifest
) {
  validate_database_source(
    path_database = path_database,
    list_build_manifest = list_build_manifest
  )

  list_pins <-
    purrr::pluck(list_build_manifest, "producer_pins", .default = list())

  # A dev pin has no tag; it is stored as missing
  data_pins <-
    tibble::tibble(
      producer = purrr::map_chr(
        .x = list_pins,
        .f = ~ purrr::chuck(.x, "artefact_id")
      ),
      tag_pinned = purrr::map_chr(
        .x = list_pins,
        .f = ~ purrr::pluck(.x, "tag", .default = NA_character_)
      )
    )

  data_rows <-
    run_with_database(
      path_database = path_database,
      fn = DBI::dbGetQuery,
      statement = base::paste(
        "SELECT producer, tag, commit_sha FROM BuildProducers",
        "WHERE version_id = (SELECT MAX(id) FROM version_control)"
      ),
      flag_read_only = TRUE
    ) |>
    tibble::as_tibble() |>
    dplyr::mutate(
      dplyr::across(.cols = c(tag, commit_sha), .fns = base::as.character)
    )

  flag_release <-
    base::identical(purrr::pluck(list_build_manifest, "profile"), "release")

  data_compared <-
    dplyr::full_join(
      x = dplyr::mutate(data_pins, is_pinned = TRUE),
      y = dplyr::mutate(data_rows, is_recorded = TRUE),
      by = "producer"
    ) |>
    dplyr::mutate(
      is_pinned = dplyr::coalesce(is_pinned, FALSE),
      is_recorded = dplyr::coalesce(is_recorded, FALSE),
      is_tag_equal = (base::is.na(tag) & base::is.na(tag_pinned)) |
        dplyr::coalesce(tag == tag_pinned, FALSE),
      is_release_complete = !flag_release |
        (
          !base::is.na(tag) & tag != "" &
            stringr::str_detect(
              dplyr::coalesce(commit_sha, ""),
              "^[0-9a-f]{40}$"
            )
        ),
      message = dplyr::case_when(
        !is_recorded ~ stringr::str_c(
          "The pinned artefact ", producer, " has no BuildProducers row."
        ),
        !is_pinned ~ stringr::str_c(
          "The BuildProducers row of ", producer,
          " has no pin in the build manifest."
        ),
        !is_tag_equal ~ stringr::str_c(
          "The BuildProducers row of ", producer, " records the tag ",
          dplyr::coalesce(tag, "(none)"), ", the pin ",
          dplyr::coalesce(tag_pinned, "(none)"), "."
        ),
        !is_release_complete ~ stringr::str_c(
          "A release build records the tag and the 40-character commit of ",
          "every producer; ", producer, " lacks one."
        ),
        .default = NA_character_
      )
    ) |>
    dplyr::arrange(producer)

  data_failed <-
    dplyr::filter(data_compared, !base::is.na(message))

  res <-
    if (
      base::nrow(data_failed) == 0L
    ) {
      build_check_result(
        check_id = "build_producers",
        scope = "BuildProducers",
        status = "pass",
        observed = base::nrow(data_rows),
        threshold = base::nrow(data_pins),
        message = "Every producer pin has its BuildProducers row."
      )
    } else {
      build_check_result(
        check_id = "build_producers",
        scope = dplyr::pull(data_failed, producer),
        status = "fail",
        observed = dplyr::pull(data_failed, tag),
        threshold = dplyr::pull(data_failed, tag_pinned),
        message = dplyr::pull(data_failed, message)
      )
    }

  return(res)
}
