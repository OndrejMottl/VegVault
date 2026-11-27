#' @title Build the file name of a producer artefact
#' @description
#' Fill the placeholders of a producer-contract file-name template, giving
#' the name under which `RUtilpol::save_latest_file()` would save the file.
#' @param name_template
#' Character scalar. File-name template with the placeholders `{date}` and
#' `{hash}` and optionally `{partition}` and `{variable}`.
#' @param date
#' A `Date` or a character scalar in the form `YYYY-MM-DD`.
#' @param hash
#' Character scalar of 32 lower-case hexadecimal characters, as returned by
#' `rlang::hash()` for the saved object.
#' @param partition
#' Character or integer scalar filling `{partition}`, or `NULL` when the
#' template has no `{partition}`.
#' @param variable_token
#' Character scalar filling `{variable}`, or `NULL` when the template has
#' no `{variable}`.
#' @return
#' Character scalar. The file name.
#' @details
#' Aborts when `date` or `hash` is malformed, or when `partition` or
#' `variable_token` is given for a template without the matching
#' placeholder, or missing for a template with it.
build_producer_file_name <- function(
  name_template,
  date,
  hash,
  partition = NULL,
  variable_token = NULL
) {
  assertthat::assert_that(
    base::is.character(name_template),
    base::length(name_template) == 1L,
    !base::is.na(name_template),
    msg = "'name_template' must be a single character value."
  )

  date_text <-
    if (
      base::inherits(date, "Date")
    ) {
      base::format(date, "%Y-%m-%d")
    } else {
      date
    }

  assertthat::assert_that(
    base::is.character(date_text),
    base::length(date_text) == 1L,
    !base::is.na(date_text),
    stringr::str_detect(date_text, "^[0-9]{4}-[0-9]{2}-[0-9]{2}$"),
    !base::is.na(base::as.Date(date_text, optional = TRUE)),
    msg = "'date' must be a Date or a value in the form YYYY-MM-DD."
  )

  assertthat::assert_that(
    base::is.character(hash),
    base::length(hash) == 1L,
    !base::is.na(hash),
    stringr::str_detect(hash, "^[0-9a-f]{32}$"),
    msg = "'hash' must be 32 lower-case hexadecimal characters."
  )

  flag_has_partition <-
    stringr::str_detect(
      string = name_template,
      pattern = stringr::fixed("{partition}")
    )

  flag_has_variable <-
    stringr::str_detect(
      string = name_template,
      pattern = stringr::fixed("{variable}")
    )

  assertthat::assert_that(
    flag_has_partition == !base::is.null(partition),
    msg = "'partition' must be given exactly when the template has one."
  )

  assertthat::assert_that(
    flag_has_variable == !base::is.null(variable_token),
    msg = "'variable_token' must be given exactly when the template has one."
  )

  assertthat::assert_that(
    base::is.null(partition) ||
      (
        base::length(partition) == 1L &&
          !base::is.na(partition) &&
          (
            base::is.character(partition) ||
              (
                base::is.numeric(partition) &&
                  partition == base::round(partition)
              )
          )
      ),
    msg = "'partition' must be a single character or whole number."
  )

  assertthat::assert_that(
    base::is.null(variable_token) ||
      (
        base::is.character(variable_token) &&
          base::length(variable_token) == 1L &&
          !base::is.na(variable_token)
      ),
    msg = "'variable_token' must be a single character value."
  )

  # A placeholder absent from the template is left untouched by its
  #   replacement, so every placeholder can be filled in one pass
  partition_text <-
    if (
      base::is.null(partition)
    ) {
      ""
    } else {
      base::format(partition, scientific = FALSE, trim = TRUE)
    }

  variable_text <-
    if (
      base::is.null(variable_token)
    ) {
      ""
    } else {
      variable_token
    }

  res <-
    name_template |>
    stringr::str_replace_all(
      pattern = stringr::fixed("{date}"),
      replacement = date_text
    ) |>
    stringr::str_replace_all(
      pattern = stringr::fixed("{hash}"),
      replacement = hash
    ) |>
    stringr::str_replace_all(
      pattern = stringr::fixed("{partition}"),
      replacement = partition_text
    ) |>
    stringr::str_replace_all(
      pattern = stringr::fixed("{variable}"),
      replacement = variable_text
    )

  return(res)
}
