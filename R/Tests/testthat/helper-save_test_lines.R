# Write lines of text to `unit_conversions.csv` in `dir_test` through a
#   binary connection, so the line ends are exactly `eol` on every system,
#   and return the path of the file.
save_test_lines <- function(vec_lines, dir_test, eol = "\n") {
  path_file <-
    base::file.path(dir_test, "unit_conversions.csv")

  con_file <-
    base::file(description = path_file, open = "wb")

  base::on.exit(base::close(con_file), add = TRUE)

  base::writeLines(text = vec_lines, con = con_file, sep = eol)

  res <- path_file

  return(res)
}
