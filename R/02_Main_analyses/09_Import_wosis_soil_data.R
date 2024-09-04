#----------------------------------------------------------#
#
#
#                       VegVault
#
#              Import WOSIS soil data
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Download, wrangel, and import soil data from WOSIS

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
    path_to_vegvault
  )


#----------------------------------------------------------#
# 2. Download data -----
#----------------------------------------------------------#

url_gh_wosis <-
  paste0(
    "https://raw.githubusercontent.com/",
    "OndrejMottl/VegVault-abiotic_data/",
    "v1.1.0/",
    "Outputs/Data/WoSIS/",
    "wosis_data_2024-08-06__e8fb256f5b70deb9576ea69806c59eb1__.qs"
  )

data_wosis <-
  dowload_and_load(url_gh_wosis)


#----------------------------------------------------------#
# 3. Add data -----
#----------------------------------------------------------#

# Datasets -----
data_wosis_raw <-
  data_wosis %>%
  dplyr::mutate(
    coord_long = as.numeric(.data$long),
    coord_lat = as.numeric(.data$lat),
    age = 0
  ) %>%
  dplyr::mutate(
    dataset_name = paste(
      "geo",
      round(.data$coord_long, digits = 2),
      round(.data$coord_lat, digits = 2),
      sep = "_"
    )
  ) %>%
  tidyr::nest(
    data_samples = c(
      "age",
      "value"
    )
  ) %>%
  dplyr::mutate(
    dataset_name = paste(
      "geo",
      round(.data$coord_long, digits = 2),
      round(.data$coord_lat, digits = 2),
      sep = "_"
    )
  ) %>%
  tidyr::unnest("data_samples") %>%
  dplyr::mutate(
    sample_name = paste0(
      .data$dataset_name,
      "_",
      .data$age
    ),
    abiotic_variable_name = .data$var_name,
    var_unit = "Unitless",
    var_reference = "https://doi.org/10.5194/soil-7-217-2021",
    var_detail = "WoSIS-SoilGrids"
  )

data_samples_db <-
  dplyr::tbl(con, "Samples") %>%
  dplyr::distinct(.data$sample_id, .data$sample_name) %>%
  dplyr::collect()

data_wosis_sub <-
  data_wosis_raw %>%
  dplyr::filter(
    .data$sample_name %in% data_samples_db$sample_name
  )

# Abiotic varibale
abiotic_variabe_id <-
  add_abiotic_variable(
    data_source = data_wosis_sub,
    con = con
  )

add_sample_abiotic_value(
  data_source = data_wosis_sub,
  con = con,
  sample_id = data_samples_db,
  abiotic_variable_id = abiotic_variabe_id
)

#----------------------------------------------------------#
# 4. Disconect DB -----
#----------------------------------------------------------#

DBI::dbDisconnect(con)
