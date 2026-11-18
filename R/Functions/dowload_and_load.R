# This function downloads a file from the internet and loads it into R.
dowload_and_load <- function(sel_url) {
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
