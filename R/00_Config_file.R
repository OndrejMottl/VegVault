#----------------------------------------------------------#
#
#
#                       VegVault
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

db_version <- "0.0.3"

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

# !!!  IMPORTANT  !!!

# This solution was created due to VegVault data not being stored
#  in publick the repository.

# Pleae download the data from the VegVault repository and place the path to it
#  in the '.secrets/path.yaml' file.

if (
  file.exists(
    here::here(".secrets/path.yaml")
  )
) {
  path_to_vegvault <-
    yaml::read_yaml(
      here::here(".secrets/path.yaml")
    ) %>%
    purrr::chuck(Sys.info()["user"])
} else {
  stop(
    paste(
      "The path to the VegVault data is not specified.",
      " Please, create a 'path.yaml' file."
    )
  )
}

#----------------------------------------------------------#
# 5. Define variables -----
#----------------------------------------------------------#


#----------------------------------------------------------#
# 6. Graphical options -----
#----------------------------------------------------------#

# define general
text_size <- 32
line_size <- 0.1
point_size <- 3

# define font
sysfonts::font_add(
  family = "Renogare",
  regular = here::here("Fonts/Renogare-Regular.otf")
)
showtext::showtext_auto()

# define output sizes
image_width <- 2450
image_height <- 1200
image_units <- "px"

# define common color
col_brown_light <- "#BC7052"
col_brown_dark <- "#8A554E"

col_green_light <- "#9BC058"
col_green_dark <- "#5D7841"

col_blue_light <- "#52758F"
col_blue_dark <- "#242531"

col_beige_light <- "#E6B482"
col_beige_dark <- "#AE8a7B"

col_white <- "white"


# set ggplot output
ggplot2::theme_set(
  ggplot2::theme_minimal() +
    ggplot2::theme(
      text = ggplot2::element_text(
        size = text_size,
        colour = col_blue_dark,
        family = "Renogare"
      ),
      line = ggplot2::element_line(
        linewidth = line_size,
        colour = col_blue_dark
      ),
      axis.text = ggplot2::element_text(
        colour = col_blue_dark,
        size = text_size,
        family = "Renogare"
      ),
      axis.title = ggplot2::element_text(
        colour = col_blue_dark,
        size = text_size,
        family = "Renogare"
      ),
      panel.grid.major = ggplot2::element_line(
        colour = col_white,
        linewidth = line_size
      ),
      panel.grid.minor = ggplot2::element_blank(),
      plot.background = ggplot2::element_rect(
        fill = col_beige_light,
        colour = col_beige_light
      ),
      panel.background = ggplot2::element_rect(
        fill = col_brown_light,
        colour = col_brown_light
      ),
    )
)
