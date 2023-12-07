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

# 2.3 dataset type

data_splot_dataset_type_id <-
  data_splot_edit %>%
  dplyr::distinct(dataset_type) %>%
  tibble::rowid_to_column() %>%
  dplyr::rename(dataset_type_id = rowid)

copy_to(
  con,
  data_splot_dataset_type_id,
  name = "DatasetTypeID",
  append = TRUE
)

data_splot_dataset_type <-
  data_splot_edit %>%
  dplyr::distinct(dataset_id, dataset_type) %>%
  dplyr::left_join(
    data_splot_dataset_type_id,
    by = dplyr::join_by(dataset_type)
  ) %>%
  dplyr::distinct(
    dataset_id, dataset_type_id
  )

copy_to(
  con,
  data_splot_dataset_type,
  name = "DatasetType",
  append = TRUE
)


# 2.4 data coordinates

data_splot_dataset_coord <-
  data_splot_edit %>%
  dplyr::distinct(dataset_id, coord_long, coord_lat)

copy_to(
  con,
  data_splot_dataset_coord,
  name = "DatasetCoord",
  append = TRUE
)

# 2.5 samples

data_splot_samples <-
  data_splot_edit %>%
  dplyr::distinct(sample_id)

copy_to(
  con,
  data_splot_samples,
  name = "Samples",
  append = TRUE
)

# 2.6 dataset-samples

data_splot_dataset_sample <-
  data_splot_edit %>%
  dplyr::distinct(dataset_id, sample_id)

copy_to(
  con,
  data_splot_dataset_sample,
  name = "DatasetSample",
  append = TRUE
)

# 2.7 sample - age

data_splot_samples_age <-
  data_splot_edit %>%
  dplyr::distinct(sample_id) %>%
  dplyr::mutate(
    age = 0
  )

copy_to(
  con,
  data_splot_samples_age,
  name = "SampleAge",
  append = TRUE
)

# 2.8 sample - details

dplyr::tbl(con, "SampleDetail") %>%
  colnames()

data_splot_samples_detail <-
  data_splot_edit %>%
  dplyr::distinct(sample_id, givd_id) %>%
  dplyr::rename(
    sample_referecne = givd_id
  ) %>%
  dplyr::mutate(
    sample_details = NA_character_
  )

copy_to(
  con,
  data_splot_samples_detail,
  name = "SampleDetail",
  append = TRUE
)


DBI::dbListTables(con)

DBI::dbDisconnect(con)


DBI::dbRemoveTable(con, "sqlite_stat1")
DBI::dbRemoveTable(con, "sqlite_stat4")

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
