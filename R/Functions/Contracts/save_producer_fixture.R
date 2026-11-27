#' @title Save a producer-artefact fixture
#' @description
#' Write the objects of one synthetic producer-artefact fixture to files,
#' in the format producers use: `qs2` content for names ending in `.qs`,
#' RDS for names ending in `.rds` and comma-separated text for names ending
#' in `.csv` (files kept in the producer repository, such as rule
#' registries).
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
#' rebuilding a fixture gives the same object when read back. `.csv` files
#' are written with `utils::write.csv()`: a header, no row names, missing
#' values as empty fields and LF line ends on every system, so a rebuilt
#' fixture is byte-identical. Aborts when a name has an extension other
#' than `.qs`, `.rds` or `.csv`, contains a directory separator, or names a
#' `.csv` file for an object that is not a data frame of atomic columns.
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
    base::all(stringr::str_detect(vec_file_names, "[.](qs|rds|csv)$")),
    !base::any(stringr::str_detect(vec_file_names, "[/\\\\]")),
    msg = stringr::str_c(
      "'list_fixture' must be a list named by file base names ending in ",
      ".qs, .rds or .csv."
    )
  )

  # A csv file holds one flat table
  vec_is_csv <-
    stringr::str_detect(vec_file_names, "[.]csv$")

  vec_is_flat <-
    purrr::map_lgl(
      .x = list_fixture,
      .f = ~ base::is.data.frame(.x) &&
        base::all(purrr::map_lgl(.x = .x, .f = base::is.atomic))
    )

  assertthat::assert_that(
    base::all(vec_is_flat[vec_is_csv]),
    msg = stringr::str_c(
      "Every .csv entry of 'list_fixture' must be a data frame of atomic ",
      "columns."
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
      } else if (
        stringr::str_detect(.y, "[.]csv$")
      ) {
        # A binary connection keeps LF line ends on Windows too
        con_csv <-
          base::file(description = .y, open = "wb")

        base::on.exit(base::close(con_csv), add = TRUE)

        utils::write.csv(
          x = .x,
          file = con_csv,
          row.names = FALSE,
          na = "",
          eol = "\n"
        )
      } else {
        base::saveRDS(object = .x, file = .y)
      }
    }
  )

  res <- vec_paths

  return(base::invisible(res))
}
