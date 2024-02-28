#----------------------------------------------------------#
#
#
#                 BIODYNAMICS - VegVault
#
#                         EDA
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# EDA of the VegVault database

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
    paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  )

DBI::dbListTables(con)

#----------------------------------------------------------#
# 2. Datasets -----
#----------------------------------------------------------#

n_datasetes <-
  dplyr::tbl(con, "Datasets") %>%
  dplyr::count() %>%
  dplyr::collect() %>%
  purrr::chuck("n")

n_datasetes_per_type <-
  dplyr::inner_join(
    dplyr::tbl(con, "Datasets"),
    dplyr::tbl(con, "DatasetTypeID"),
    by = "dataset_type_id"
  ) %>%
  dplyr::group_by(dataset_type) %>%
  dplyr::count(name = "N") %>%
  dplyr::collect() %>%
  dplyr::ungroup()

plot_waffle(
  n_datasetes_per_type,
  dataset_type,
  plot_title = "Datasets type",
  one_point_is = 1e3,
  n_rows = 50
)

n_datasetes_per_type %>%
  ggplot2::ggplot(
    ggplot2::aes(
      y = N,
      x = reorder(dataset_type, -N)
    )
  ) +
  ggplot2::scale_y_continuous(
    trans = "log10",
    breaks = scales::trans_breaks("log10", function(x) 10^x),
    labels = scales::trans_format("log10", scales::math_format(10^.x))
  ) +
  ggplot2::labs(
    title = "Datasets type",
    x = "",
    y = "Number of datasets"
  ) +
  ggplot2::geom_segment(
    ggplot2::aes(
      xend = dataset_type,
      yend = 0
    ),
    color = "grey"
  ) +
  ggplot2::geom_point(
    size = 3,
    shape = 21,
    col = "black",
    fill = "white"
  ) +
  ggplot2::geom_label(
    ggplot2::aes(
      label = scales::number(N)
    ),
    vjust = -0.5,
    size = 3
  )

n_datasetes_per_source_type <-
  dplyr::inner_join(
    dplyr::tbl(con, "Datasets"),
    dplyr::tbl(con, "DatasetSourceTypeID"),
    by = "data_source_type_id"
  ) %>%
  dplyr::group_by(dataset_source_type) %>%
  dplyr::count(name = "N") %>%
  dplyr::collect() %>%
  dplyr::ungroup()

plot_waffle(
  n_datasetes_per_source_type,
  dataset_source_type,
  plot_title = "Datasets source type",
  one_point_is = 1e3,
  n_rows = 50
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
  dplyr::ungroup()

n_datasetes_per_type_per_source_type %>%
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
  ) %>%
  ggplot2::ggplot(
    ggplot2::aes(
      y = N,
      x = dataset_source_type # reorder(dataset_source_type, -N)
    )
  ) +
  ggplot2::scale_y_continuous(
    trans = "log10",
    breaks = scales::trans_breaks("log10", function(x) 10^x),
    labels = scales::trans_format("log10", scales::math_format(10^.x))
  ) +
  ggplot2::labs(
    title = "Datasets type per source type",
    x = "",
    y = "Number of datasets"
  ) +
  ggplot2::guides(
    fill = "none"
  ) +
  ggplot2::facet_wrap(~dataset_type, nrow = 1, scales = "free_x") +
  ggplot2::geom_segment(
    mapping = ggplot2::aes(
      x = dataset_source_type, # reorder(dataset_source_type, -N),
      xend = dataset_source_type, # reorder(dataset_source_type, -N),
      yend = 0
    ),
    color = "grey",
    position = ggplot2::position_dodge(0.5)
  ) +
  ggplot2::geom_point(
    mapping = ggplot2::aes(
      fill = dataset_source_type
    ),
    size = 3,
    shape = 21,
    col = "black",
    position = ggplot2::position_dodge(0.5)
  ) +
  ggplot2::geom_label(
    mapping = ggplot2::aes(
      label = scales::number(N)
    ),
    vjust = -0.5,
    size = 3,
    position = ggplot2::position_dodge(0.5)
  )
