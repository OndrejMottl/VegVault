#' @title Compute the SHA-256 checksum of a text file
#' @description
#' Hash the text of a file with SHA-256 after normalising its line endings
#' to LF, so that one committed file gives the same checksum in a Windows
#' checkout (CRLF) and in a Linux checkout (LF). Used to fingerprint the
#' files of a producer's copy of the VegVault contracts.
#' @param path_file
#' Character scalar. Path of an existing file.
#' @return
#' Character scalar of 64 lower-case hexadecimal characters.
#' @details
#' Every carriage return (CR) directly followed by a line feed (LF) is
#' removed before hashing; a CR elsewhere is kept. The file is read whole,
#' so the function suits source and contract files, not large artefacts,
#' whose bytes `compute_file_sha256()` hashes. It hashes with
#' `cli::hash_raw_sha256()`, so a producer's copy of the contract functions
#' needs no package beyond those of the validator.
#' @seealso [compute_file_sha256()]
#' @examples
#' \dontrun{
#' compute_text_file_sha256(
#'   path_file = here::here("Data", "Contracts", "splot_plots.yml")
#' )
#' }
compute_text_file_sha256 <- function(path_file) {
  assertthat::assert_that(
    base::is.character(path_file),
    base::length(path_file) == 1L,
    !base::is.na(path_file),
    base::file.exists(path_file),
    !base::dir.exists(path_file),
    msg = "`path_file` must be the path of an existing file."
  )

  vec_bytes <-
    base::readBin(
      con = path_file,
      what = "raw",
      n = base::file.size(path_file)
    )

  # A CR byte (0x0d) is dropped only where an LF byte (0x0a) follows it
  is_cr_before_lf <-
    vec_bytes == base::as.raw(13L) &
      c(vec_bytes[-1L] == base::as.raw(10L), FALSE)

  vec_bytes_lf <-
    vec_bytes[!is_cr_before_lf]

  res <-
    cli::hash_raw_sha256(x = vec_bytes_lf) |>
    stringr::str_to_lower()

  return(res)
}
