#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#                     Config file
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#
# Configuration script with the variables that should be consistent throughout
#   the whole repo. It loads packages, defines important variables,
#   authorises the user, and saves config file.

# Set the current environment
current_env <- environment()

# set seed
set.seed(1234)


#----------------------------------------------------------#
# 1. Load packages -----
#----------------------------------------------------------#

if (
  isFALSE(
    exists("already_synch", envir = current_env)
  )
) {
  already_synch <- FALSE
}

if (
  isFALSE(already_synch)
) {
  library(here)
  # Synchronise the package versions
  renv::restore(
    lockfile = here::here("renv/library_list.lock")
  )
  already_synch <- TRUE

  # Save snapshot of package versions
  # renv::snapshot(lockfile =  "renv/library_list.lock")  # do only for update
}

# Define packages
package_list <-
  c(
    "assertthat",
    "DBI",
    "here",
    "httpgd",
    "janitor",
    "jsonlite",
    "knitr",
    "languageserver",
    "renv",
    "remotes",
    "rlang",
    "roxygen2",
    "RSQLite",
    "tidyverse",
    "tinytable",
    "usethis",
    "utils"
  )

# Attach all packages
sapply(package_list, library, character.only = TRUE)


#----------------------------------------------------------#
# 2. Define space -----
#----------------------------------------------------------#

current_date <- Sys.Date()

# project directory is set up by 'here' package, Adjust if needed
current_dir <- here::here()


#----------------------------------------------------------#
# 3. Load functions -----
#----------------------------------------------------------#

# get vector of general functions
fun_list <-
  list.files(
    path = "R/Functions/",
    pattern = "*.R",
    recursive = TRUE
  )

# source them
if (
  length(fun_list) > 0
) {
  sapply(
    paste0("R/functions/", fun_list, sep = ""),
    source
  )
}


#----------------------------------------------------------#
# 4. Authorise the user -----
#----------------------------------------------------------#

auth_table <-
  readr::read_delim(
    here::here(
      ".secrets/path.txt"
    ),
    show_col_types = FALSE
  )

data_storage_path <-
  auth_table %>%
  dplyr::filter(
    user == Sys.info()["user"] &
      nodename == Sys.info()["nodename"]
  ) %>%
  purrr::pluck("path")


#----------------------------------------------------------#
# 5. Define variables -----
#----------------------------------------------------------#


#----------------------------------------------------------#
# 6. Graphical options -----
#----------------------------------------------------------#

## examples
# set ggplot output
ggplot2::theme_set(
  ggplot2::theme_bw()
)

# define general
text_size <- 10
line_size <- 0.1

# define output sizes
image_width <- 16
image_height <- 12
image_units <- "cm"

# define pallets

# define common color
