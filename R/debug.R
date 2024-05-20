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


data_climate_dataset_raw$age %>% summary()


DBI::dbRemoveTable(con, "AbioticData")

DBI::dbExecute(
  conn = con,
  statement = sql_query_split[23]
)

dplyr::tbl(con, "AbioticData")


class(tibble::tibble(x = 1:10))

dummy <-
  structure(
    list(
      data = tibble::tibble(),
      db_con = con
    ),
    class = c("list", "my_class")
  )

tibble::tibble() %>%
  class()

print.my_class <- function(x, ...) {
  print(x$data)
}
test

class()

# install.packages("devtools")
devtools::install_github("r-lib/sloop")


# testing new functions

open_vault <- function(path) {
  # test various things

  db_con <-
    DBI::dbConnect(
      RSQLite::SQLite(),
      path
    )

  dummy <-
    structure(
      list(
        data = tibble::tibble(),
        db_con = db_con
      ),
      class = c("list", "vault_pipe")
    )

  return(dummy)
}

get_datasets <- function(con) {
  sel_data <- con$data

  if (
    nrow(sel_data) > 0
  ) {
    stop("Vault already has some data. `get_datasets()` should be selected first")
  }

  # test various things
  sel_con <- con$db_con

  dat_res <-
    dplyr::tbl(sel_con, "Datasets")

  res <-
    structure(
      list(
        data = dat_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}

select_dataset_by_type <- function(con, sel_type) {
  # test various things

  sel_data <- con$data

  sel_con <- con$db_con

  dat_res <-
    sel_data %>%
    dplyr::inner_join(
      dplyr::tbl(sel_con, "DatasetTypeID"),
      by = "dataset_type_id"
    ) %>%
    dplyr::filter(
      dataset_type %in% sel_type
    )

  res <-
    structure(
      list(
        data = dat_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}

select_dataset_by_geo <- function(con, long_lim = c(-180, 180), lat_lim = c(-90, 90)) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data


  long_lim_min <- as.numeric(eval(min(long_lim)))
  long_lim_max <- as.numeric(eval(max(long_lim)))

  lat_lim_min <- as.numeric(eval(min(lat_lim)))
  lat_lim_max <- as.numeric(eval(max(lat_lim)))


  assertthat::assert_that(
    all(c("coord_long", "coord_lat") %in% colnames(sel_data))
  )

  data_filter <-
    sel_data %>%
    dplyr::filter(!is.na(coord_long)) %>%
    dplyr::filter(!is.na(coord_lat))

  data_res <-
    data_filter %>%
    dplyr::filter(
      coord_long >= long_lim_min
    ) %>%
    dplyr::filter(
      coord_long <= long_lim_max
    ) %>%
    dplyr::filter(
      coord_lat >= lat_lim_min
    ) %>%
    dplyr::filter(
      coord_lat <= lat_lim_max
    )

  res <-
    structure(
      list(
        data = data_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}

get_samples <- function(con) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  data_res <-
    sel_data %>%
    dplyr::inner_join(
      dplyr::tbl(sel_con, "DatasetSample"),
      by = "dataset_id"
    ) %>%
    dplyr::inner_join(
      dplyr::tbl(sel_con, "Samples"),
      by = "sample_id"
    )

  res <-
    structure(
      list(
        data = data_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}

get_taxa <- function(con) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  data_res <-
    sel_data %>%
    dplyr::inner_join(
      dplyr::tbl(sel_con, "SampleTaxa"),
      by = "sample_id"
    )

  res <-
    structure(
      list(
        data = data_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}

select_by_taxa <- function(con, sel_taxa) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  data_res <-
    sel_data %>%
    dplyr::inner_join(
      dplyr::tbl(sel_con, "Taxa"),
      by = "taxon_id"
    ) %>%
    dplyr::filter(
      taxon_name %in% sel_taxa
    )

  res <-
    structure(
      list(
        data = data_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}

harmonise_taxa <- function(con, to = c("original", "species", "genus", "family")) {
  # test various things
  sel_con <- con$db_con

  sel_data <- con$data

  to_long <- switch(to,
    species = "taxon_species",
    genus = "taxon_genus",
    family = "taxon_family",
  )

  data_class_sub <-
    dplyr::tbl(sel_con, "TaxonClassification") %>%
    dplyr::select(
      taxon_id,
      dplyr::all_of(to_long)
    ) %>%
    dplyr::rename(
      taxon_id_new = !!to_long
    )

  data_res <-
    sel_data %>%
    dplyr::inner_join(
      data_class_sub,
      by = "taxon_id"
    ) %>%
    dplyr::select(
      -taxon_id
    ) %>%
    dplyr::rename(
      taxon_id = taxon_id_new
    )

  res <-
    structure(
      list(
        data = data_res,
        db_con = sel_con
      ),
      class = c("list", "vault_pipe")
    )

  return(res)
}

extract_data <- function(con) {
  # test various things
  sel_data <- con$data

  sel_data %>%
    dplyr::collect() %>%
    return()
}

plan_na_plots_picea <-
  open_vault(
    path = paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  ) %>%
  get_datasets() %>%
  select_dataset_by_type(
    sel_type = c(
      "vegetation_plot",
      "fossil_pollen_archive"
    )
  ) %>%
  select_dataset_by_geo(
    lat_lim = c(22, 60),
    long_lim = c(-135, -60)
  ) %>%
  get_samples() %>%
  get_taxa() %>%
  harmonise_taxa(to = "genus") %>%
  select_by_taxa(sel_taxa = c("Picea"))


data_na_plots_picea <-
  extract_data(plan_na_plots_picea)

time_step <- 2500

data_dummy <-
  tidyr::expand_grid(
    data_na_plots_picea %>%
      dplyr::distinct(coord_long, coord_lat),
    age_bin = seq(0, 15e3, time_step)
  )


fig_na_plots_picea <-
  data_na_plots_picea %>%
  dplyr::distinct(
    dataset_type, dataset_id, coord_long, coord_lat, sample_id, age
  ) %>%
  dplyr::filter(age >= 0 & age <= 15e3) %>%
  dplyr::mutate(
    age_bin = floor(age / time_step) * time_step
  ) %>%
  dplyr::mutate(
    age_bin_class = dplyr::case_when(
      .default = paste("paleo:", age_bin),
      dataset_type == "vegetation_plot" ~ "modern",
    ),
    age_bin_class = factor(age_bin_class,
      levels = c("modern", paste("paleo:", seq(0, 15e3, time_step)))
    )
  ) %>%
  ggplot2::ggplot(
    mapping = ggplot2::aes(
      x = coord_long,
      y = coord_lat,
    )
  ) +
  ggplot2::borders(
    fill = "grey80"
  ) +
  ggplot2::geom_point(
    data = data_dummy,
    shape = 20,
    size = 1,
    col = "grey50",
  ) +
  ggplot2::geom_point(
    col = "blue",
    size = 1
  ) +
  ggplot2::facet_wrap(
    ~age_bin_class
  ) +
  ggplot2::theme_minimal() +
  ggplot2::coord_quickmap(
    xlim = c(-135, -60),
    ylim = c(22, 60)
  )

ggplot2::ggsave(
  here::here("Outputs/Figures/fig_test.png"),
  plot = fig_test,
  width = 10,
  height = 10,
  bg = "white"
)
