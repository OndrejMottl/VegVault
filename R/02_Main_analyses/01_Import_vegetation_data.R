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

url_gh <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/BIODYNAMICS-Vegetation_data/",
    "main/Outputs/Data/"
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

DBI::dbListTables(con)


#----------------------------------------------------------#
# 2. Splot -----
#----------------------------------------------------------#

url_splot <-
  paste0(
    url_gh,
    "data_splot_2023-12-06__cbf9022330b5d47a5c76bf7ca6b226b4__.qs"
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

data_splot <-
  qs::qread(
    file = paste0(
      tempdir(),
      "/",
      "data_splot.qs"
    )
  )

dplyr::glimpse(data_splot)

data_splot_edit <-
  data_splot %>%
  dplyr::mutate(
    dataset_id = paste0(
      "splot_",
      plot_observation_id
    ),
    coord_long = longitude,
    coord_lat = latitude,
    data_source_desc = givd_id,
    dataset_type = "splot",
    sampling_method_details = givd_id,
    sample_id = paste0(
      "splot_",
      dplyr::row_number()
    ),
  )

# 2.1 - dataset id
splot_dataset_id <-
  data_splot_edit %>%
  dplyr::arrange(plot_observation_id) %>%
  dplyr::distinct(dataset_id)

copy_to(
  con,
  splot_dataset_id,
  name = "Datasets",
  append = TRUE
)

# 2.2 dataset source

data_splot_data_source_id <-
  data_splot_edit %>%
  dplyr::distinct(data_source_desc) %>%
  tibble::rowid_to_column() %>%
  dplyr::rename(data_source_id = rowid)

copy_to(
  con,
  data_splot_data_source_id,
  name = "DatasetSourcesID",
  append = TRUE
)

data_splot_data_sources <-
  data_splot_edit %>%
  dplyr::arrange(plot_observation_id) %>%
  dplyr::distinct(dataset_id, data_source_desc) %>%
  dplyr::left_join(
    data_splot_data_source_id,
    by = dplyr::join_by(data_source_desc)
  ) %>%
  dplyr::distinct(
    data_source_id, dataset_id
  )

copy_to(
  con,
  data_splot_data_sources,
  name = "DatasetSources",
  append = TRUE
)


#----------------------------------------------------------#
# 3. BIEN -----
#----------------------------------------------------------#


url_bien <-
  paste0(
    url_gh,
    "data_bien_2023-12-06__7893b8a80ceb1550103667f95b695e6b__.qs"
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
