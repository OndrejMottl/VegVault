#' @title Resolve one pinned release file in the download cache
#' @description
#' Return the cached copy of one pinned release file when its checksum is
#' the pinned one, and download it otherwise.
#' @param file_name
#' Character scalar. The file name.
#' @param sha256
#' Character scalar. The pinned SHA-256 of the file.
#' @param dir_cache
#' Character scalar. The download cache; the file belongs at
#' `<dir_cache>/<sha256>/<file_name>`.
#' @param url_template,repository,tag,directory
#' Passed to `build_release_url()` to locate the file when it has to be
#' downloaded.
#' @return
#' Character scalar: `<dir_cache>/<sha256>/<file_name>`.
#' @details
#' A cached file whose checksum differs (for example a broken copy) is
#' downloaded again by `save_release_file()`, which aborts on a failed
#' download or a checksum mismatch.
#' @examples
#' \dontrun{
#' resolve_release_file(
#'   file_name = file_name,
#'   sha256 = sha256,
#'   dir_cache = dir_cache,
#'   url_template = url_template,
#'   repository = "OndrejMottl/VegVault-Trait_data",
#'   tag = "v2.0.0",
#'   directory = "Outputs/Data"
#' )
#' }
resolve_release_file <- function(
  file_name,
  sha256,
  dir_cache,
  url_template,
  repository,
  tag,
  directory
) {
  assertthat::assert_that(
    base::is.character(file_name),
    base::length(file_name) == 1L,
    base::is.character(sha256),
    base::length(sha256) == 1L,
    base::is.character(dir_cache),
    base::length(dir_cache) == 1L,
    msg = "`file_name`, `sha256` and `dir_cache` must be character scalars."
  )

  path_cache <-
    base::file.path(dir_cache, sha256, file_name)

  is_cached <-
    base::file.exists(path_cache) &&
    base::identical(compute_file_sha256(path_file = path_cache), sha256)

  res <-
    if (
      is_cached
    ) {
      path_cache
    } else {
      save_release_file(
        url = build_release_url(
          url_template = url_template,
          repository = repository,
          tag = tag,
          directory = directory,
          file_name = file_name
        ),
        path_cache = path_cache,
        sha256_expected = sha256
      )
    }

  return(res)
}
