#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#                  Import Vegetation data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import neo-ecological vegetation data

#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

# Load configuration
source(
  here::here(
    "R/00_Config_file.R"
  )
)


#----------------------------------------------------------#
# 1. Connect to db -----
#----------------------------------------------------------#

con <-
  DBI::dbConnect(
    RSQLite::SQLite(),
    here::here(
      "Data/SQL/VegVault.sqlite"
    )
  )


#----------------------------------------------------------#
# 2. download the files -----
#----------------------------------------------------------#

url_gh <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-Vegetation_data/",
    "main/Outputs/Data/"
  )

url_bien <-
  paste0(
    url_gh,
    "data_bien_2023-12-06__7893b8a80ceb1550103667f95b695e6b__.qs"
  )

url_splot <-
  paste0(
    url_gh,
    "data_splot_2023-12-06__cbf9022330b5d47a5c76bf7ca6b226b4__.qs"
  )

download.file(
  url = url_bien,
  destfile = paste0(
    tempdir(),
    "/",
    "data_bien.qs"
  ),
  method = "curl"
)

download.file(
  url = url_splot,
  destfile = paste0(
    tempdir(),
    "/",
    "data_splot.qs"
  ),
  method = "curl"
)

#----------------------------------------------------------#
# 2. Splot -----
#----------------------------------------------------------#

data_splot <-
  qs::qread(
    file = paste0(
      tempdir(),
      "/",
      "data_splot.qs"
    )
  )

data_splot_edit <-
  data_splot %>%
  dplyr::mutate(
    dataset_id = paste0(
      "splot_",
      plot_observation_id
    ),
    sample_id = paste0(
      "splot_",
      dplyr::row_number()
    )
  )

data_splot$plot_observation_id %>%
  unique() %>%
  length()


data_splot$givd_id %>%
  unique() %>%
  length()
