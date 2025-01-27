#----------------------------------------------------------#
#
#
#                       VegVault
#
#                      MNS figures
#               Example of gridpoints resolution
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#


#----------------------------------------------------------#
# 0. Load configuration -----
#----------------------------------------------------------#

library(here)

source(
  here::here(
    "R/00_Config_file.R"
  )
)

source(
  here::here(
    "R/03_Visualisation/01_manuscript/00_Config_mns.R"
  )
)

x_lim <- c(12, 18.9)
y_lim <- c(48.5, 51.1)

x_lim_min <- min(x_lim)
x_lim_max <- max(x_lim)
y_lim_min <- min(y_lim)
y_lim_max <- max(y_lim)

ext_europe <- c(-15, 45, 35, 72)

#----------------------------------------------------------#
# 1. Get data -----
#----------------------------------------------------------#

data_cz_border <-
  geodata::gadm(
    country = "CZE",
    resolution = 2,
    path = tempdir(),
    level = 0
  ) %>%
  sf::st_as_sf()

data_grid_coord <-
  dplyr::inner_join(
    dplyr::tbl(con, "Datasets"),
    dplyr::tbl(con, "DatasetTypeID"),
    by = "dataset_type_id"
  ) %>%
  dplyr::filter(dataset_type == "gridpoints") %>%
  dplyr::filter(
    coord_long >= !!rlang::enquo(x_lim_min) &
      coord_long <= !!rlang::enquo(x_lim_max)
  ) %>%
  dplyr::filter(
    coord_lat >= !!rlang::enquo(y_lim_min) &
      coord_lat <= !!rlang::enquo(y_lim_max)
  )

# Acess the VegVault file
data_example_bio1 <-
  vaultkeepr::open_vault(
    path = path_to_vegvault # [config]
  ) %>%
  # Add the dataset information
  vaultkeepr::get_datasets() %>%
  # Select modern plot data and climate
  vaultkeepr::select_dataset_by_type(
    sel_dataset_type = c(
      "vegetation_plot",
      "gridpoints"
    )
  ) %>%
  # Limit data to Czech Republic
  vaultkeepr::select_dataset_by_geo(
    lat_lim = y_lim,
    long_lim = x_lim,
    verbose = FALSE
  ) %>%
  # Add samples
  vaultkeepr::get_samples() %>%
  # select only modern data
  vaultkeepr::select_samples_by_age(
    age_lim = c(0, 0),
    verbose = FALSE
  ) %>%
  # Add abiotic data
  vaultkeepr::get_abiotic_data(verbose = FALSE) %>%
  # Select only Mean Anual Temperature (bio1)
  vaultkeepr::select_abiotic_var_by_name(sel_var_name = "bio1") %>%
  vaultkeepr::extract_data(
    return_raw_data = TRUE,
    verbose = FALSE
  )

data_gridpoints_abiotic <-
  data_example_bio1 %>%
  dplyr::filter(dataset_type == "gridpoints") %>%
  dplyr::select(sample_id, coord_long, coord_lat, sample_id_link) %>%
  dplyr::rename_with(
    .fn = ~ paste0(.x, "_grid")
  )

data_vegetation <-
  data_example_bio1 %>%
  dplyr::filter(dataset_type == "vegetation_plot") %>%
  dplyr::select(sample_id, coord_long, coord_lat) %>%
  dplyr::rename_with(
    .fn = ~ paste0(.x, "_veg")
  )

data_links <-
  data_gridpoints_abiotic %>%
  dplyr::left_join(
    data_vegetation,
    by = c("sample_id_link_grid" = "sample_id_veg")
  )

#----------------------------------------------------------#
# 2. Plot -----
#----------------------------------------------------------#

fif_template <-
  tibble::tibble() %>%
  ggplot2::ggplot() +
  ggplot2::borders(
    fill = col_grey,
    col = NA
  ) +
  ggplot2::labs(
    x = "Longitude",
    y = "Latitude"
  ) +
  ggplot2::geom_sf(
    data = data_cz_border,
    fill = NA,
    colour = "red"
  )

fig_europe <-
  fif_template +
  ggplot2::scale_y_continuous(breaks = seq(35, 70, by = 10)) +
  ggplot2::scale_x_continuous(breaks = seq(-10, 45, by = 10)) +

  ggplot2::coord_sf(
    xlim = ext_europe[1:2],
    ylim = ext_europe[3:4]
  )

fif_template_cz <-
  fif_template +
  ggplot2::scale_y_continuous(breaks = seq(48, 51, by = 1)) +
  ggplot2::scale_x_continuous(breaks = seq(12, 19, by = 2)) +
  ggplot2::coord_sf(
    xlim = x_lim,
    ylim = y_lim
  )

fig_data_grid_coord_cz <-
  fif_template_cz +
  ggplot2::geom_point(
    data = data_grid_coord %>%
      dplyr::collect(),
    mapping = ggplot2::aes(
      x = coord_long,
      y = coord_lat
    ),
    shape = 15,
    size = point_size / 6,
    alpha = 1,
    col = col_brown_neutral
  )

fig_gridpoint_links_cz <-
  fif_template_cz +
  ggplot2::geom_segment(
    data = data_links,
    mapping = ggplot2::aes(
      x = coord_long_grid,
      y = coord_lat_grid,
      xend = coord_long_veg,
      yend = coord_lat_veg
    ),
    col = col_blue_dark,
    linewidth = line_size
  ) +
  ggplot2::geom_point(
    data = data_gridpoints_abiotic,
    mapping = ggplot2::aes(
      x = coord_long_grid,
      y = coord_lat_grid
    ),
    shape = 15,
    alpha = 1,
    size = point_size / 6,
    col = col_brown_neutral
  ) +
  ggplot2::geom_point(
    data = data_vegetation,
    mapping = ggplot2::aes(
      x = coord_long_veg,
      y = coord_lat_veg
    ),
    shape = 20,
    alpha = 0.5,
    size = point_size / 3,
    col = col_green_dark # [config]
  )


fig_gridpoints_example <-
  cowplot::plot_grid(
    fig_europe,
    cowplot::plot_grid(
      fig_data_grid_coord_cz,
      fig_gridpoint_links_cz,
      ncol = 1,
      nrow = 2
    ),
    ncol = 2,
    nrow = 1,
    rel_widths = c(1, 1)
  )

save_mns_figure(
  sel_plot = fig_gridpoints_example,
  image_width = list_img_width$full, # [config]
  image_height = 120
)
