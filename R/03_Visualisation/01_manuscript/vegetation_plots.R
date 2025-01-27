#----------------------------------------------------------#
#
#
#                       VegVault
#
#                      MNS figures
#                 Vegetation plots Summary
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


#----------------------------------------------------------#
# 1. Get data -----
#----------------------------------------------------------#

data_vegetation_samples <-
  vaultkeepr::open_vault(
    path = path_to_vegvault # [config]
  ) %>%
  # Add the dataset information
  vaultkeepr::get_datasets() %>%
  # Select modern plot data and climate
  vaultkeepr::select_dataset_by_type(
    sel_dataset_type = c(
      "vegetation_plot",
      "fossil_pollen_archive"
    )
  ) %>%
  # Add samples
  vaultkeepr::get_samples() %>%
  # select only modern data
  # Add abiotic data
  vaultkeepr::extract_data(
    return_raw_data = TRUE,
    verbose = FALSE
  ) %>%
  dplyr::mutate(
    dataset_type = stringr::str_replace_all(
      dataset_type,
      "_",
      " "
    )
  )

data_vegetation_samples_space <-
  data_vegetation_samples %>%
  dplyr::distinct(dataset_type, coord_long, coord_lat)

data_vegetation_samples_time <-
  data_vegetation_samples %>%
  dplyr::distinct(dataset_id, dataset_type, age)


#----------------------------------------------------------#
# 2. Plot -----
#----------------------------------------------------------#
fig_world_empty <-
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
  ggplot2::scale_y_continuous(breaks = seq(-90, 90, by = 30)) +
  ggplot2::scale_x_continuous(breaks = seq(-180, 180, by = 60))

fig_vegetation_space <-
  fig_world_empty +
  ggplot2::geom_point(
    data = data_vegetation_samples_space,
    mapping = ggplot2::aes(
      x = coord_long,
      y = coord_lat,
      col = dataset_type
    ),
    size = point_size / 10, # [config]
    alpha = 0.5
  ) +
  ggplot2::scale_color_manual(
    values = palette_dataset_type # [config]
  ) +
  ggplot2::guides(
    color = ggplot2::guide_legend(override.aes = list(size = point_size))
  ) +
  ggplot2::theme(
    legend.position = "top",
  ) +
  ggplot2::coord_sf()

# alternative time figure using density
if (
  FALSE
) {
  fig_vegetation_time <-
    data_vegetation_samples_time %>%
    ggplot2::ggplot(
      ggplot2::aes(
        x = age,
        y = ggplot2::after_stat(count)
      )
    ) +
    ggplot2::geom_density(
      ggplot2::aes(
        fill = dataset_type
      ),
      alpha = 0.75,
      adjust = 5
    ) +
    ggplot2::scale_fill_manual(
      values = palette_dataset_type # [config]
    ) +
    ggplot2::scale_x_continuous(
      transform = scales::transform_log1p(),
      breaks = c(0, 100, 1e3, 5e3, 10e3, 20e3),
      labels = c("0", 0.1, 1, 5, 10, 20)
    ) +
    ggplot2::scale_y_continuous(
      transform = scales::transform_log1p(),
      breaks = c(1, 10, 100, 1e3, 10e3, 100e3),
      labels = c("1", "10", "100", "1e3", "1e4", "1e5")
    ) +
    ggplot2::guides(
      color = ggplot2::guide_legend(override.aes = list(size = point_size))
    ) +
    ggplot2::theme(
      legend.position = "top"
    ) +
    ggplot2::labs(
      x = "Age (ka cal yr BP)",
      y = "Number of Samples",
      fill = "Dataset Type"
    )
}

fig_vegetation_time <-
  data_vegetation_samples_time %>%
  ggplot2::ggplot(
    ggplot2::aes(
      x = age,
      y = ggplot2::after_stat(count)
    )
  ) +
  ggplot2::geom_histogram(
    ggplot2::aes(
      fill = dataset_type
    ),
    alpha = 1,
    bins = 20
  ) +
  ggplot2::scale_fill_manual(
    values = palette_dataset_type # [config]
  ) +
  ggplot2::scale_y_continuous(
    transform = scales::transform_log1p(),
    breaks = c(1, 10, 100, 1e3, 1e4, 1e5, 1e6, 1e7, 1e8, 1e9),
    labels = c("1", "10", "100", "1e3", "1e4", "1e5", "1e6", "1e7", "1e8", "1e9")
  ) +
  ggplot2::scale_x_continuous(
    breaks = seq(0, 20e3, by = 5e3),
    labels = seq(0, 20, by = 5)
  ) +
  ggplot2::coord_cartesian(
    xlim = c(0.2, 20e3),
    ylim = c(1, 1e9)
  ) +
  ggplot2::guides(
    color = ggplot2::guide_legend(override.aes = list(size = point_size))
  ) +
  ggplot2::theme(
    legend.position = "top"
  ) +
  ggplot2::labs(
    x = "Age (ka cal yr BP)",
    y = "Number of Samples",
    fill = "Dataset Type"
  )

fig_legend <-
  cowplot::get_plot_component(
    fig_vegetation_time,
    "guide-box-top",
    return_all = TRUE
  )

fig_vegetation <-
  cowplot::plot_grid(
    fig_vegetation_space +
      ggplot2::theme(
        legend.position = "none"
      ),
    fig_vegetation_time +
      ggplot2::theme(
        legend.position = "none"
      ),
    nrow = 1,
    rel_widths = c(1.5, 1)
  ) %>%
  cowplot::plot_grid(
    fig_legend,
    .,
    nrow = 2,
    rel_heights = c(0.1, 1)
  )

save_mns_figure(
  sel_plot = fig_vegetation,
  image_width = list_img_width$full, # [config]
  image_height = 90
)
