#' @title Save a release file into the download cache
#' @description
#' Download one pinned release file, check its SHA-256 against the
#' manifest, and only then put it at its place in the download cache.
#' @param url
#' Character scalar. The URL of the file (see `build_release_url()`); a
#' `file://` URL serves as a local stand-in in tests.
#' @param path_cache
#' Character scalar. Where the file goes, normally
#' `<cache>/<sha256>/<file_name>`; its folder is created when missing.
#' @param sha256_expected
#' Character scalar. The SHA-256 of the file in the manifest.
#' @return
#' Character scalar: `path_cache`.
#' @details
#' The file is downloaded with `curl` to `<path_cache>.partial`, which is
#' moved to `path_cache` only when its checksum equals `sha256_expected`,
#' replacing a file already there. On a failed download or a checksum
#' mismatch the partial file is deleted and the function aborts with a
#' message naming the file.
#' @examples
#' \dontrun{
#' save_release_file(
#'   url = url_release,
#'   path_cache = base::file.path(dir_cache, sha256, file_name),
#'   sha256_expected = sha256
#' )
#' }
save_release_file <- function(
  url,
  path_cache,
  sha256_expected
) {
  assertthat::assert_that(
    base::is.character(url),
    base::length(url) == 1L,
    !base::is.na(url),
    base::nzchar(url),
    msg = "`url` must be a non-empty character scalar."
  )

  assertthat::assert_that(
    base::is.character(path_cache),
    base::length(path_cache) == 1L,
    !base::is.na(path_cache),
    msg = "`path_cache` must be a character scalar."
  )

  assertthat::assert_that(
    base::is.character(sha256_expected),
    base::length(sha256_expected) == 1L,
    stringr::str_detect(sha256_expected, "^[0-9a-f]{64}$") %in% TRUE,
    msg = "`sha256_expected` must be 64 lower-case hexadecimal characters."
  )

  file_name <-
    base::basename(path_cache)

  path_partial <-
    stringr::str_c(path_cache, ".partial")

  base::dir.create(
    path = base::dirname(path_cache),
    recursive = TRUE,
    showWarnings = FALSE
  )

  # A partial file never stays behind, whatever happens below
  base::on.exit(base::unlink(path_partial), add = TRUE)

  # A failed curl download warns and returns a non-zero status
  status_download <-
    base::tryCatch(
      expr = base::suppressWarnings(
        utils::download.file(
          url = url,
          destfile = path_partial,
          method = "curl",
          quiet = TRUE,
          mode = "wb"
        )
      ),
      error = function(error) {
        -1L
      }
    )

  if (
    !base::identical(base::as.integer(status_download), 0L) ||
      !base::file.exists(path_partial)
  ) {
    cli::cli_abort(
      "The release file {.file {file_name}} could not be downloaded."
    )
  }

  sha256_downloaded <-
    compute_file_sha256(path_file = path_partial)

  if (
    !base::identical(sha256_downloaded, sha256_expected)
  ) {
    cli::cli_abort(
      c(
        "The release file {.file {file_name}} does not match its checksum
        in the producer manifest.",
        "i" = "Expected {sha256_expected}, got {sha256_downloaded}."
      )
    )
  }

  flag_moved <-
    base::file.rename(from = path_partial, to = path_cache)

  if (
    !flag_moved
  ) {
    cli::cli_abort(
      "The release file {.file {file_name}} could not be put in the cache."
    )
  }

  res <- path_cache

  return(res)
}
