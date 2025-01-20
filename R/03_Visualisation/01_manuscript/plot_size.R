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


#----------------------------------------------------------#
# 1. Get data -----
#----------------------------------------------------------#

plot_size_types <-
  dplyr::tbl(con, "SampleSizeID") %>%
  dplyr::distinct(description) %>%
  dplyr::collect()

data_samples_plot_size <-
  dplyr::inner_join(
    dplyr::tbl(con, "Datasets"),
    dplyr::tbl(con, "DatasetTypeID"),
    by = "dataset_type_id"
  ) %>%
  dplyr::filter(
    dataset_type == "vegetation_plot"
  ) %>%
  dplyr::inner_join(
    dplyr::tbl(con, "DatasetSample"),
    by = "dataset_id"
  ) %>%
  dplyr::inner_join(
    dplyr::tbl(con, "Samples"),
    by = "sample_id"
  ) %>%
  dplyr::left_join(
    dplyr::tbl(con, "SampleSizeID"),
    by = "sample_size_id"
  ) %>%
  dplyr::select(sample_size) %>%
  dplyr::collect()


#----------------------------------------------------------#
# 1. Plot -----
#----------------------------------------------------------#

fig_samples_plot_size <-
  data_samples_plot_size %>%
  ggplot2::ggplot(
    ggplot2::aes(
      x = sample_size,
    )
  ) +
  ggplot2::scale_x_continuous(
    trans = "log10"
  ) +
  ggplot2::scale_y_continuous(
    trans = "log10",
    breaks = scales::trans_breaks("log10", function(x) 10^x),
    labels = scales::trans_format("log10", scales::math_format(10^.x))
  ) +
  ggplot2::labs(
    x = paste0("Plot size (", plot_size_types$description, ")"),
    y = "Number of Samples"
  ) +
  ggplot2::geom_histogram(
    fill = col_grey, # [config]
    col = NA,
    bins = 15
  )

save_mns_figure(
  sel_plot = fig_samples_plot_size,
  image_width = list_img_width$single, # [config]
  image_height = 60
)
