#----------------------------------------------------------#
#
#
#                       VegVault
#
#                      MNS figures
#                 {vaultkeepr} example I
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# To retrieve data for the genus Picea across North America by selecting both
#   modern and fossil pollen plot datasets, filtering samples by geographic
#   boundaries and temporal range (0 to 15,000 yr BP), and harmonizing taxa to
#   the genus level

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

time_step <- 2500

x_lim_na <- c(-135, -60)
y_lim_na <- c(22, 60)

y_lim_cz <- c(48.5, 51.1)
x_lim_cz <- c(12, 18.9)

y_lim_la <- c(-53, 28)
x_lim_la <- c(-110, -38)

#----------------------------------------------------------#
# 1. Get data -----
#----------------------------------------------------------#

## 1.3 North America Picea -----

data_na_plots_picea <-
  # Access the VegVault
  vaultkeepr::open_vault(
    path = path_to_vegvault # [config]
  ) %>%
  # Start by adding dataset information
  vaultkeepr::get_datasets() %>%
  # Select both modern and paleo plot data
  vaultkeepr::select_dataset_by_type(
    sel_dataset_type = c(
      "vegetation_plot",
      "fossil_pollen_archive"
    )
  ) %>%
  # Limit data to North America
  vaultkeepr::select_dataset_by_geo(
    lat_lim = y_lim_na,
    long_lim = x_lim_na,
    verbose = FALSE
  ) %>%
  # Add samples
  vaultkeepr::get_samples() %>%
  # Limit the samples by age
  vaultkeepr::select_samples_by_age(
    age_lim = c(0, 12e3),
    verbose = FALSE
  ) %>%
  # Add taxa & classify all data to a genus level
  vaultkeepr::get_taxa(
    classify_to = "genus"
  ) %>%
  # Extract only Picea data
  vaultkeepr::select_taxa_by_name(sel_taxa = "Picea") %>%
  vaultkeepr::extract_data(
    return_raw_data = TRUE,
    verbose = FALSE
  ) %>%
  dplyr::filter(
    dataset_type %in% c("vegetation_plot", "fossil_pollen_archive")
  ) %>%
  dplyr::select(
    dataset_id, dataset_type, coord_long, coord_lat, sample_id, age,
    taxon_name, value
  ) %>%
  dplyr::filter(
    taxon_name == "Picea",
    value > 0
  ) %>%
  dplyr::distinct(
    dataset_id, dataset_type, coord_long, coord_lat, age
  ) %>%
  dplyr::mutate(
    age_bin = (floor(age / time_step) * time_step) / 1e3
  ) %>%
  dplyr::mutate(
    age_bin_class = dplyr::case_when(
      .default = paste("paleo:", age_bin, "ka cal yr BP"),
      dataset_type == "vegetation_plot" ~ "contemporary",
    ),
    age_bin_class = factor(age_bin_class,
      levels = c(
        "contemporary",
        paste(
          "paleo:",
          seq(0, 10, time_step / 1e3),
          "ka cal yr BP"
        )
      )
    ),
    dataset_type = stringr::str_replace_all(
      dataset_type,
      "_",
      " "
    )
  )

## 1.2 CZ JSDM -----

data_cz_jsdm_raw <-
  # Acess the VegVault file
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
    lat_lim = y_lim_cz,
    long_lim = x_lim_cz,
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
  # add taxa
  vaultkeepr::get_taxa() %>%
  vaultkeepr::extract_data(
    return_raw_data = TRUE,
    verbose = FALSE
  )

data_cz_climate <-
  data_cz_jsdm_raw %>%
  dplyr::distinct(
    sample_id, sample_id_link, abiotic_variable_unit, abiotic_value
  ) %>%
  tidyr::drop_na()

data_cz_plots <-
  data_cz_jsdm_raw %>%
  dplyr::filter(dataset_type == "vegetation_plot") %>%
  dplyr::filter(value > 0) %>%
  dplyr::distinct(
    sample_id, coord_long, coord_lat, taxon_id
  ) %>%
  tidyr::drop_na() %>%
  dplyr::group_by(sample_id, coord_long, coord_lat) %>%
  dplyr::count(name = "n_taxa") %>%
  dplyr::ungroup() %>%
  dplyr::filter(n_taxa > 1)

data_cz_jsdm <-
  data_cz_plots %>%
  dplyr::left_join(
    data_cz_climate,
    by = dplyr::join_by("sample_id" == "sample_id_link")
  )

## 1.3 Latin America traits -----

data_la_traits_raw <-
  # Acess the VegVault file
  vaultkeepr::open_vault(
    path = path_to_vegvault # [config]
  ) %>%
  # Add the dataset information
  vaultkeepr::get_datasets() %>%
  # Select modern plot data and climate
  vaultkeepr::select_dataset_by_type(
    sel_dataset_type = c(
      "fossil_pollen_archive",
      "traits"
    )
  ) %>%
  # Limit data to South and Central America
  vaultkeepr::select_dataset_by_geo(
    lat_lim = y_lim_la,
    long_lim = x_lim_la,
    sel_dataset_type = c(
      "fossil_pollen_archive",
      "traits"
    ),
    verbose = FALSE
  ) %>%
  # Add samples
  vaultkeepr::get_samples() %>%
  # Limit to 6-12 ka yr BP
  vaultkeepr::select_samples_by_age(
    age_lim = c(6e3, 12e3),
    verbose = FALSE
  ) %>%
  # add taxa & clasify all data to a genus level
  vaultkeepr::get_taxa(classify_to = "genus") %>%
  # add trait information & clasify all data to a genus level
  vaultkeepr::get_traits(
    classify_to = "genus",
    verbose = FALSE
  ) %>%
  # Only select the plant height
  vaultkeepr::select_traits_by_domain_name(
    sel_domain = "Plant heigh"
  ) %>%
  vaultkeepr::extract_data(
    return_raw_data = TRUE,
    verbose = FALSE
  )

data_la_datasets <-
  data_la_traits_raw %>%
  dplyr::filter(dataset_type == "fossil_pollen_archive") %>%
  dplyr::distinct(dataset_id, sample_id, age) %>%
  dplyr::group_by(dataset_id) %>%
  dplyr::summarise(
    .groups = "drop",
    age_min = min(age),
    age_mean = mean(age),
    age_max = max(age)
  )

data_la_taxa <-
  data_la_traits_raw %>%
  dplyr::filter(
    dataset_type %in% c("vegetation_plot", "fossil_pollen_archive")
  ) %>%
  dplyr::select(
    dataset_id, coord_long, coord_lat, sample_id, taxon_id, value
  ) %>%
  dplyr::filter(value > 0) %>%
  dplyr::distinct(
    dataset_id, sample_id, coord_long, coord_lat, taxon_id
  ) %>%
  tidyr::drop_na() %>%
  dplyr::group_by(dataset_id, sample_id, coord_long, coord_lat) %>%
  dplyr::count(name = "n_taxa") %>%
  dplyr::ungroup() %>%
  dplyr::filter(n_taxa > 1)

data_la_height <-
  data_la_traits_raw %>%
  dplyr::filter(dataset_type == "traits") %>%
  tidyr::drop_na(trait_value) %>%
  dplyr::select(taxon_id_trait, trait_value) %>%
  dplyr::group_by(taxon_id_trait) %>%
  dplyr::summarise(
    mean_value = mean(trait_value)
  ) %>%
  tidyr::drop_na(mean_value)

#----------------------------------------------------------#
# 2. Plot -----
#----------------------------------------------------------#

## 2.1 North America Picea -----

fig_na_picea <-
  data_na_plots_picea %>%
  ggplot2::ggplot() +
  ggplot2::coord_quickmap(
    xlim = x_lim_na,
    ylim = y_lim_na
  ) +
  ggplot2::labs(
    y = "Latitude",
    x = "Longitude",
    col = "Dataset type"
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
  ggplot2::borders(
    fill = col_grey, # [config]
    col = col_black, # [config]
    size = line_size / 2 # [config]
  ) +
  ggplot2::geom_point(
    mapping = ggplot2::aes(
      x = coord_long,
      y = coord_lat,
      col = dataset_type
    ),
    size = point_size # [config]
  ) +
  ggplot2::geom_point(
    mapping = ggplot2::aes(
      x = coord_long,
      y = coord_lat,
    ),
    col = col_black, # [config]
    size = point_size / 10 # [config]
  ) +
  ggplot2::facet_wrap(
    ~age_bin_class
  )

save_mns_figure(
  sel_plot = fig_na_picea,
  image_width = list_img_width$full, # [config]
  image_height = 140
)


## 2.2 CZ JSDM -----

fig_cz_jsdm <-
  ggplot2::ggplot(
    mapping = ggplot2::aes(
      x = coord_long,
      y = coord_lat
    )
  ) +
  ggplot2::coord_quickmap(
    xlim = x_lim_cz,
    ylim = y_lim_cz
  ) +
  ggplot2::labs(
    x = "Longtitude",
    y = "Latitude",
    colour = "MAT (°C)",
    size = "Species richness",
  ) +
  ggplot2::scale_colour_steps(
    low = col_brown_neutral, # [config]
    high = "red" # [config]
  ) +
  ggplot2::scale_size_continuous(
    breaks = scales::pretty_breaks(n = 5),
    range = c(
      0.2,
      point_size * 2 # [config]
    )
  ) +
  ggplot2::theme(
    legend.position = "top"
  ) +
  ggplot2::borders(
    fill = col_grey, # [config]
    col = NA,
    size = line_size / 2 # [config]
  ) +
  ggplot2::geom_vline(
    xintercept = seq(min(x_lim_cz), max(x_lim_cz), 2),
    linewidth = line_size,
    colour = col_white
  ) +
  ggplot2::geom_hline(
    yintercept = seq(min(y_lim_cz), max(y_lim_na), 0.5),
    linewidth = line_size,
    colour = col_white
  ) +
  ggplot2::borders(
    fill = NA,
    col = col_black, # [config]
    size = line_size / 2 # [config]
  ) +
  ggplot2::geom_point(
    data = data_cz_jsdm,
    mapping = ggplot2::aes(
      col = abiotic_value
      # size = n_taxa
    ),
    size = point_size # [config]
  ) +
  ggplot2::geom_point(
    data = data_cz_jsdm,
    col = col_black, # [config]
    size = point_size / 10 # [config]
  )

save_mns_figure(
  sel_plot = fig_cz_jsdm,
  image_width = list_img_width$double, # [config]
  image_height = 120
)

## 2.3 Latin America traits -----

fig_la_datasets <-
  data_la_datasets %>%
  ggplot2::ggplot(
    mapping = ggplot2::aes(
      y = reorder(dataset_id, -age_mean),
      yend = reorder(dataset_id, -age_mean),
      x = age_min,
      xend = age_max
    )
  ) +
  ggplot2::geom_segment(
    linewidth = line_size * 10, # [config]
    col = col_black # [config]
  ) +
  ggplot2::geom_point(
    mapping = ggplot2::aes(
      x = age_min
    ),
    col = col_purple_light, # [config]
    size = point_size # [config]
  ) +
  ggplot2::geom_point(
    mapping = ggplot2::aes(
      x = age_max
    ),
    col = col_purple_light, # [config]
    size = point_size # [config]
  ) +
  ggplot2::theme(
    axis.text.y = ggplot2::element_blank(),
    axis.ticks.y = ggplot2::element_blank(),
    legend.title = ggplot2::element_blank(),
    legend.position = "none",
    panel.grid.major.y = ggplot2::element_blank()
  ) +
  ggplot2::scale_x_continuous(
    transform = "reverse",
    breaks = seq(12e3, 6e3, -2e3),
    labels = seq(12, 6, -2)
  ) +
  ggplot2::labs(
    x = "Age (ka cal yr BP)",
    y = "Datasets"
  )

fig_la_taxa <-
  data_la_taxa %>%
  ggplot2::ggplot(
    mapping = ggplot2::aes(
      x = 1,
      y = n_taxa
    )
  ) +
  ggplot2::geom_violin(
    fill = col_green_dark, # [config]
    col = col_grey # [config]
  ) +
  ggplot2::geom_boxplot(
    width = 0.2,
    outlier.shape = NA,
    fill = col_white, # [config]
    col = col_black # [config]
  ) +
  ggplot2::theme(
    axis.title.x = ggplot2::element_blank(),
    axis.text.x = ggplot2::element_blank(),
    axis.ticks.x = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    legend.title = ggplot2::element_blank(),
    legend.position = "none"
  ) +
  ggplot2::labs(
    y = "N genera per Sample"
  ) +
  ggplot2::scale_y_continuous(
    labels = scales::label_number(),
    breaks = c(1, 5, 10, 20, 30, 50, 70),
    limits = c(0, 60)
  )

fig_la_height <-
  data_la_height %>%
  ggplot2::ggplot(
    mapping = ggplot2::aes(
      x = 1,
      y = mean_value
    )
  ) +
  ggplot2::geom_violin(
    fill = col_dark_blue, # [config]
    col = col_grey # [config]
  ) +
  ggplot2::geom_boxplot(
    width = 0.2,
    outlier.shape = NA,
    fill = col_white, # [config]
    col = col_black # [config]
  ) +
  ggplot2::theme(
    axis.title.x = ggplot2::element_blank(),
    axis.text.x = ggplot2::element_blank(),
    axis.ticks.x = ggplot2::element_blank(),
    panel.grid.major.x = ggplot2::element_blank(),
    legend.title = ggplot2::element_blank(),
    legend.position = "none"
  ) +
  ggplot2::labs(
    y = "Average Plant Height \n per genera"
  ) +
  ggplot2::scale_y_continuous(
    transform = scales::transform_pseudo_log(),
    labels = scales::label_number(),
    breaks = c(0, 1, 5, 10, 20, 30, 50, 70),
    limits = c(0, 80)
  )

fig_la_traits <-
  cowplot::plot_grid(
    fig_la_datasets,
    fig_la_taxa,
    fig_la_height,
    nrow = 1,
    align = "h",
    axis = "bt",
    rel_widths = c(2, 1, 1)
  )

save_mns_figure(
  sel_plot = fig_la_traits,
  image_width = list_img_width$full, # [config]
  image_height = 120
)

#----------------------------------------------------------#
# 3. Merged plot -----
#----------------------------------------------------------#

fig_vaultkeepr_examples <-
  cowplot::plot_grid(
    fig_na_picea,
    cowplot::plot_grid(
      fig_cz_jsdm,
      fig_la_traits,
      nrow = 1,
      rel_widths = c(1.1, 1)
    ),
    nrow = 2,
    rel_heights = c(1.5, 1)
  )

# alternative layout
if (
  FALSE
) {
  fig_vaultkeepr_examples <-
    cowplot::plot_grid(
      fig_na_picea,
      cowplot::plot_grid(
        fig_cz_jsdm,
        fig_la_traits,
        nrow = 2,
        rel_heights = c(1, 1)
      ),
      nrow = 1,
      rel_widths = c(1.3, 1)
    )
}

save_mns_figure(
  sel_plot = fig_vaultkeepr_examples,
  image_width = list_img_width$full, # [config]
  image_height = 220
)
