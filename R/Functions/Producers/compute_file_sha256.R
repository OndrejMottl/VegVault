#' @title Compute the SHA-256 checksum of a file
#' @description
#' Hash the bytes of a file with SHA-256, the checksum the producer pin
#' manifest records for every release file.
#' @param path_file
#' Character scalar. Path of an existing file.
#' @return
#' Character scalar of 64 lower-case hexadecimal characters.
#' @details
#' Uses `secretbase::sha256()` on the file, which streams it, so large
#' artefacts are not read into memory.
#' @examples
#' \dontrun{
#' compute_file_sha256(path_file = path_artefact)
#' }
compute_file_sha256 <- function(path_file) {
  assertthat::assert_that(
    base::is.character(path_file),
    base::length(path_file) == 1L,
    !base::is.na(path_file),
    base::file.exists(path_file),
    !base::dir.exists(path_file),
    msg = "`path_file` must be the path of an existing file."
  )

  res <-
    secretbase::sha256(file = path_file) |>
    base::as.character() |>
    stringr::str_to_lower()

  return(res)
}
