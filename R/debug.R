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
    paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  )

DBI::dbListTables(con)

# There are ceratin taxa that are unable to be classified.
# These are removed from the list and classified separately
dplyr::filter(
  !taxon_name %in% c(
    "Atriplex hortensis",
    "Hydrocotyle bonariensis",
    "Rorippa xsterilis",
    "x Festulolium",
    "x Agropogon",
    "x Triticale",
    "x Pucciphippsia"
  )
)

AbioticVariable_current <-
  dplyr::tbl(con, "AbioticVariable") %>%
  dplyr::collect()

AbioticVariable_new <-
  tibble::tribble(
    ~abiotic_variable_id, ~abiotic_variable_name, ~abiotic_variable_unit, ~measure_details,
    1, "bio1", "°C", "CHELSA",
    2, "bio4", "°C", "CHELSA",
    3, "bio6", "°C", "CHELSA",
    4, "bio12", "kg m-2 year-1", "CHELSA",
    5, "bio15", "Unitless", "CHELSA",
    6, "bio18", "kg m-2 quarter-1", "CHELSA",
    7, "bio19", "kg m-2 quarter-1", "CHELSA",
    8, "HWSD2", "Unitless", "WoSIS-SoilGrids"
  ) %>%
  dplyr::mutate(
    abiotic_variable_id = as.integer(abiotic_variable_id)
  )

DBI::dbRemoveTable(con, "AbioticVariable")


DBI::dbExecute(
  conn = con,
  statement = sql_query_split[24]
)



add_to_db(con, AbioticVariable_new, "AbioticVariable")


data_climate_dataset_raw$age  %>% summary()


DBI::dbRemoveTable(con, "AbioticData")

DBI::dbExecute(
  conn = con,
  statement = sql_query_split[23]
)

 dplyr::tbl(con, "AbioticData")
