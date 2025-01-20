#----------------------------------------------------------#
#
#
#                       VegVault
#
#                      MNS figures
#                   Datasets summary
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

n_datasetes_per_type <-
  dplyr::inner_join(
    dplyr::tbl(con, "Datasets"),
    dplyr::tbl(con, "DatasetTypeID"),
    by = "dataset_type_id"
  ) %>%
  dplyr::group_by(dataset_type) %>%
  dplyr::count(name = "N") %>%
  dplyr::collect() %>%
  dplyr::ungroup() %>%
  dplyr::mutate(
    dataset_type = stringr::str_replace_all(
      dataset_type,
      "_",
      " "
    )
  )

n_datasetes_per_type_per_source_type <-
  dplyr::inner_join(
    dplyr::tbl(con, "Datasets"),
    dplyr::tbl(con, "DatasetTypeID"),
    by = "dataset_type_id"
  ) %>%
  dplyr::inner_join(
    dplyr::tbl(con, "DatasetSourceTypeID"),
    by = "data_source_type_id"
  ) %>%
  dplyr::group_by(dataset_type, dataset_source_type) %>%
  dplyr::count(name = "N") %>%
  dplyr::collect() %>%
  dplyr::ungroup() %>%
  dplyr::mutate(
    dataset_type = stringr::str_replace_all(
      dataset_type,
      "_",
      " "
    ),
    dataset_source_type = dplyr::case_when(
      .default = dataset_source_type,
      dataset_source_type == "FOSSILPOL" ~ "Neotoma - FOSSILPOL"
    )
  ) %>%
  dplyr::group_by(dataset_type) %>%
  dplyr::mutate(
    n_datasetes_per_type = sum(N)
  ) %>%
  dplyr::ungroup() %>%
  dplyr::arrange(-n_datasetes_per_type, -N) %>%
  dplyr::mutate(
    dataset_type = factor(
      dataset_type,
      levels = unique(dataset_type)
    ),
    dataset_source_type = factor(
      dataset_source_type,
      levels = unique(dataset_source_type)
    )
  )

#----------------------------------------------------------#
# 2. Plot -----
#----------------------------------------------------------#

fig_n_datasetes_per_type <-
  plot_waffle(
    n_datasetes_per_type,
    dataset_type,
    one_point_is = 1e3,
    col_background = col_white,
    col_lines = col_black,
    legend_position = "top",
    legend_n_col = 2,
    data_point_name = "Datasets"
  ) +
  ggplot2::scale_fill_manual(
    values = palette_dataset_type
  )

fig_n_datasetes_per_type_per_source_type <-
  n_datasetes_per_type_per_source_type %>%
  ggplot2::ggplot(
    ggplot2::aes(
      y = N,
      x = dataset_source_type # reorder(dataset_source_type, -N)
    )
  ) +
  ggplot2::theme(
    panel.grid.major.x = ggplot2::element_blank()
  ) +
  ggplot2::scale_y_continuous(
    transform = scales::transform_log10(),
    breaks = scales::trans_breaks("log10", function(x) 10^x),
    labels = scales::trans_format("log10", scales::math_format(10^.x)),
    limits = c(1, 10e6)
  ) +
  ggplot2::labs(
    x = "Data Source",
    y = "Number of Datasets"
  ) +
  ggplot2::theme(
    legend.position = "none",
    strip.background = ggplot2::element_rect(
      fill = col_white,
      colour = col_grey # [config]
    ),
    strip.text = ggplot2::element_text(
      colour = col_black # [config]
    ),
    axis.text.x = ggplot2::element_blank()
  ) +
  ggplot2::scale_fill_manual(
    values = palette_dataset_source_type # [config]
  ) +
  ggplot2::facet_wrap(
    ~dataset_type,
    nrow = 1,
    scales = "free_x"
  ) +
  ggplot2::geom_segment(
    mapping = ggplot2::aes(
      x = dataset_source_type, # reorder(dataset_source_type, -N),
      xend = dataset_source_type, # reorder(dataset_source_type, -N),
      yend = 0
    ),
    color = col_black, # [config]
    position = ggplot2::position_dodge(0.5)
  ) +
  ggplot2::geom_point(
    mapping = ggplot2::aes(
      fill = dataset_source_type
    ),
    size = point_size,
    shape = 21,
    col = col_black, # [config]
    position = ggplot2::position_dodge(0.5)
  ) +
  ggplot2::geom_label(
    mapping = ggplot2::aes(
      label = scales::number(N)
    ),
    vjust = -0.5,
    size = point_size,
    position = ggplot2::position_dodge(0.5)
  ) +
  ggplot2::geom_text(
    mapping = ggplot2::aes(
      y = 2,
      label = dataset_source_type,
    ),
    hjust = 0,
    vjust = 0,
    angle = 90,
    size = point_size,
    position = ggplot2::position_dodge(0.5)
  )


fig_n_datasetes_per_type_per_source_type_colored <-
  color_facets(
    sel_plot = fig_n_datasetes_per_type_per_source_type,
    #  # need to manually sort the colors due to previous reorder
    sel_palette = c(
      palette_dataset_type["traits"],
      palette_dataset_type["gridpoints"],
      palette_dataset_type["vegetation plot"],
      palette_dataset_type["fossil pollen archive"]
    ),
    direction = "horizontal",
    return_raw = TRUE
  )

fig_datasets <-
  cowplot::plot_grid(
    fig_n_datasetes_per_type,
    fig_n_datasetes_per_type_per_source_type_colored,
    ncol = 2,
    nrow = 1,
    rel_widths = c(1, 2)
  )

save_mns_figure(
  sel_plot = fig_datasets,
  image_width = list_img_width$full, # [config]
  image_height = 120
)
