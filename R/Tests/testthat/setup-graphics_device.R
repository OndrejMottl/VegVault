# Figure tests draw plots to measure them; without an open device R would
#   write them to Rplots.pdf in this folder
grDevices::pdf(file = base::tempfile(fileext = ".pdf"))

withr::defer(
  grDevices::dev.off(),
  envir = testthat::teardown_env()
)
