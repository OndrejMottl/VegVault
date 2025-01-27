#----------------------------------------------------------#
#
#
#                       VegVault
#
#                      MNS figures
#                 Vegetation plot size
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

sel_dataset_for_example <- 91256


#----------------------------------------------------------#
# 1. Get data -----
#----------------------------------------------------------#

dataset_age_example <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::filter(dataset_id == sel_dataset_for_example) %>%
  dplyr::inner_join(
    dplyr::tbl(con, "DatasetSample"),
    by = "dataset_id"
  ) %>%
  dplyr::inner_join(
    dplyr::tbl(con, "Samples"),
    by = "sample_id"
  ) %>%
  dplyr::distinct(sample_id, age) %>%
  dplyr::collect()

dataset_age_example_iterations <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::filter(dataset_id == sel_dataset_for_example) %>%
  dplyr::inner_join(
    dplyr::tbl(con, "DatasetSample"),
    by = "dataset_id"
  ) %>%
  dplyr::inner_join(
    dplyr::tbl(con, "Samples"),
    by = "sample_id"
  ) %>%
  dplyr::distinct(sample_id) %>%
  dplyr::inner_join(
    dplyr::tbl(con, "SampleUncertainty"),
    by = "sample_id"
  ) %>%
  dplyr::select(
    sample_id,
    age_it = age
  ) %>%
  dplyr::collect()


#----------------------------------------------------------#
# 1. Plot -----
#----------------------------------------------------------#

fig_sample_age <-
  dplyr::left_join(
    dataset_age_example_iterations,
    dataset_age_example,
    by = "sample_id"
  ) %>%
  dplyr::group_by(sample_id, age) %>%
  dplyr::summarise(
    .groups = "drop",
    age_it_min = min(age_it),
    age_it_max = max(age_it)
  ) %>%
  ggplot2::ggplot(
    mapping = ggplot2::aes(
      y = age,
      group = as.factor(age),
      x = age
    )
  ) +
  ggplot2::coord_fixed(
    xlim = c(0, 20e3),
    ylim = c(0, 12e3)
  ) +
  ggplot2::labs(
    y = "Sample age (ka cal yr BP)",
    x = "Potential age of Samples (ka cal yr BP)",
      caption = paste0(
      "Dataset ID:",
      as.character(sel_dataset_for_example)
    ),
  ) +
  ggplot2::scale_x_continuous(
    breaks = seq(0, 20e3, 5e3),
    labels = seq(0, 20, 5)
  ) +
  ggplot2::scale_y_continuous(
    breaks = seq(0, 18e3, 5e3),
    labels = seq(0, 18, 5)
  ) +
  ggplot2::geom_segment(
    mapping = ggplot2::aes(
      x = age_it_min,
      xend = age_it_max,
      yend = age
    ),
    col = col_grey,
  ) +
  ggplot2::geom_point(
    shape = 21,
    fill = col_purple,
    size = point_size,
    col = col_black
  ) 

save_mns_figure(
  sel_plot = fig_sample_age,
  image_width = list_img_width$double, # [config]
  image_height = 130
)




