#' @title Load an R object from a URL
#' @description
#' Download a producer artefact (`.rds` or `.qs`) from a URL into the
#' temporary folder of the session and read it.
#' @param sel_url
#' Character scalar. URL of the file. A URL containing `.qs` is read with
#' `qs2::qs_read()`, any other as RDS.
#' @return
#' The R object stored in the file.
#' @details
#' The file is saved in `tempdir()` under the cleaned name of the last URL
#' segment (`RUtilpol::get_clean_name()`), downloaded with
#' `download.file(method = "curl")`. Producer artefacts are written by
#' `{RUtilpol}` with `{qs2}` under the `.qs` extension; legacy `{qs}`
#' files cannot be read on R 4.6 or later.
#' @examples
#' \dontrun{
#' data_artefact <-
#'   load_remote_artefact(sel_url = "https://example.org/data.qs")
#' }
load_remote_artefact <- function(sel_url) {
  file_format <- "rds"
  if (
    stringr::str_detect(sel_url, ".qs")
  ) {
    file_format <- "qs"
  }

  name_clean <-
    stringr::str_extract(sel_url, "/([^/]+)$") %>%
    stringr::str_replace(., "/", "") %>%
    RUtilpol::get_clean_name(.)

  file_full_path <-
    paste0(
      tempdir(),
      "/",
      name_clean,
      ".",
      file_format
    )

  download.file(
    url = sel_url,
    destfile = file_full_path,
    method = "curl"
  )


  if (
    file_format == "qs"
  ) {
    # Producer artefacts are written by {RUtilpol} with {qs2} under the
    #   `.qs` extension; legacy {qs} files are not supported on R >= 4.6
    data_load <-
      qs2::qs_read(
        file = file_full_path
      )
  } else {
    data_load <-
      readr::read_rds(
        file = file_full_path
      )
  }
  return(data_load)
}
