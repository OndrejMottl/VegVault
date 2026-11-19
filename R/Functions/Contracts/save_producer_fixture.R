#' @title Save a producer-artefact fixture
#' @description
#' Write the objects of one synthetic producer-artefact fixture to files,
#' in the format producers use: `qs2` content for names ending in `.qs`
#' and RDS for names ending in `.rds`.
#' @param list_fixture
#' A named list of data frames, as returned by the `build_*_fixture()`
#' functions: every name is the file base name to write.
#' @param dir_output
#' Character scalar. Existing directory that receives the files.
#' @param flag_overwrite
#' Logical. If `FALSE` (default), the function aborts when any of the
#' files already exists, before writing anything.
#' @return
#' Invisibly, a character vector of the paths written, in the order of
#' `list_fixture`.
#' @details
#' `qs2` files are written with `qs2::qs_save()` using one thread, so
#' rebuilding a fixture gives the same object when read back. Aborts when a
#' name has an extension other than `.qs` or `.rds`, or contains a
#' directory separator.
save_producer_fixture <- function(
  list_fixture,
  dir_output,
  flag_overwrite = FALSE
) {
  vec_file_names <-
    base::names(list_fixture)

  assertthat::assert_that(
    base::is.list(list_fixture),
    !base::is.data.frame(list_fixture),
    !base::is.null(vec_file_names),
    !base::anyNA(vec_file_names),
    !base::anyDuplicated(vec_file_names),
    base::all(stringr::str_detect(vec_file_names, "[.](qs|rds)$")),
    !base::any(stringr::str_detect(vec_file_names, "[/\\\\]")),
    msg = stringr::str_c(
      "'list_fixture' must be a list named by file base names ending in ",
      ".qs or .rds."
    )
  )

  assertthat::assert_that(
    base::is.character(dir_output),
    base::length(dir_output) == 1L,
    base::dir.exists(dir_output),
    msg = "'dir_output' must be an existing directory."
  )

  assertthat::assert_that(
    base::is.logical(flag_overwrite),
    base::length(flag_overwrite) == 1L,
    !base::is.na(flag_overwrite),
    msg = "'flag_overwrite' must be TRUE or FALSE."
  )

  vec_paths <-
    base::file.path(dir_output, vec_file_names)

  vec_existing <-
    vec_file_names[base::file.exists(vec_paths)]

  if (
    !flag_overwrite && base::length(vec_existing) > 0L
  ) {
    cli::cli_abort(
      c(
        "Fixture file{?s} already exist{?s/}: {.file {vec_existing}}.",
        "i" = "Set {.arg flag_overwrite} to TRUE to replace them."
      )
    )
  }

  purrr::walk2(
    .x = list_fixture,
    .y = vec_paths,
    .f = ~ {
      if (
        stringr::str_detect(.y, "[.]qs$")
      ) {
        qs2::qs_save(object = .x, file = .y, nthreads = 1L)
      } else {
        base::saveRDS(object = .x, file = .y)
      }
    }
  )

  res <- vec_paths

  return(base::invisible(res))
}
