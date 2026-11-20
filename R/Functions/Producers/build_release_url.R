#' @title Build the download URL of a release file
#' @description
#' Fill the URL template of the release fetch route with the producer
#' repository, the tag, the directory and the file name of one file.
#' @param url_template
#' Character scalar. The template, with the placeholders `{repository}`,
#' `{tag}`, `{directory}` and `{file_name}`, for example
#' `producers: release_url_template` of `config.yml`, the raw GitHub file
#' at the tag:
#' `"https://raw.githubusercontent.com/{repository}/{tag}/"` followed by
#' `"{directory}/{file_name}"`.
#' @param repository
#' Character scalar. The producer repository, such as
#' `"OndrejMottl/VegVault-Trait_data"`.
#' @param tag
#' Character scalar. A release tag (see `is_release_tag()`).
#' @param directory
#' Character scalar. The directory of the file in the repository.
#' @param file_name
#' Character scalar. The file name.
#' @return
#' Character scalar: the URL.
#' @details
#' Aborts when the template lacks `{tag}` or `{file_name}`, when a
#' placeholder is left unfilled, or when `tag` is not a release tag.
#' @examples
#' \dontrun{
#' build_release_url(
#'   url_template = load_config_value(
#'     value = c("producers", "release_url_template")
#'   ),
#'   repository = "OndrejMottl/VegVault-Trait_data",
#'   tag = "v2.0.0",
#'   directory = "Outputs/Data",
#'   file_name = "data_trait_try_2026-01-01__0123__.qs"
#' )
#' }
build_release_url <- function(
  url_template,
  repository,
  tag,
  directory,
  file_name
) {
  list_values <-
    list(
      url_template = url_template,
      repository = repository,
      tag = tag,
      directory = directory,
      file_name = file_name
    )

  is_text_scalar <-
    purrr::map_lgl(
      .x = list_values,
      .f = ~ base::is.character(.x) &&
        base::length(.x) == 1L &&
        !base::is.na(.x) &&
        base::nzchar(.x)
    )

  assertthat::assert_that(
    base::all(is_text_scalar),
    msg = stringr::str_c(
      "`",
      stringr::str_flatten(
        base::names(is_text_scalar)[!is_text_scalar],
        collapse = "`, `"
      ),
      "` must be non-empty character scalars."
    )
  )

  if (
    !is_release_tag(tag)
  ) {
    cli::cli_abort(
      "{.arg tag} must be a release tag such as {.val v2.0.0}, not
      {.val {tag}}."
    )
  }

  if (
    !stringr::str_detect(url_template, stringr::fixed("{tag}")) ||
      !stringr::str_detect(url_template, stringr::fixed("{file_name}"))
  ) {
    cli::cli_abort(
      "The URL template needs the placeholders {{tag}} and {{file_name}}."
    )
  }

  url_filled <-
    url_template |>
    stringr::str_replace_all(
      pattern = stringr::fixed("{repository}"),
      replacement = repository
    ) |>
    stringr::str_replace_all(
      pattern = stringr::fixed("{tag}"),
      replacement = tag
    ) |>
    stringr::str_replace_all(
      pattern = stringr::fixed("{directory}"),
      replacement = directory
    ) |>
    stringr::str_replace_all(
      pattern = stringr::fixed("{file_name}"),
      replacement = file_name
    )

  vec_placeholders_left <-
    stringr::str_extract_all(url_filled, "\\{[^{}]*\\}") |>
    base::unlist()

  if (
    base::length(vec_placeholders_left) > 0L
  ) {
    # The braces are removed so that cli does not read them as glue
    vec_names_left <-
      stringr::str_remove_all(vec_placeholders_left, "[{}]")

    cli::cli_abort(
      "The URL template has unknown placeholders: {.val {vec_names_left}}."
    )
  }

  res <- url_filled

  return(res)
}
