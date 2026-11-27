#----------------------------------------------------------#
#
#
#                       VegVault
#
#           Figure of the data extraction (website)
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#
# Draws the figure of the data extraction with {vaultkeepr} on the
#   website: the database and the package, then the steps of a query with
#   the functions of each step. The layout is below, in mm from the bottom
#   left corner; file, size, DOI, background and fonts come from
#   `website: extraction_workflow` in config.yml, the colours from
#   colors.json, the logos from Data/Website/Logos and
#   Outputs/Figures/website, and the icons from Font Awesome Free (CC BY
#   4.0, credited in the figure). The figure is replaced. Run from the
#   repository root:
#
#   Rscript R/Website/render_extraction_workflow.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

list_settings <-
  load_config_value(value = c("website", "extraction_workflow"))

# colors.json may carry an alpha value; the figure takes #RRGGBB
list_colors <-
  load_figure_colors(path_colors = here::here("colors.json")) |>
  purrr::map(.f = ~ stringr::str_sub(.x, start = 1L, end = 7L))

list_fonts <-
  base::list(
    text = purrr::chuck(list_settings, "font_text"),
    code = purrr::chuck(list_settings, "font_code")
  )

width_mm <- purrr::chuck(list_settings, "width_mm")
height_mm <- purrr::chuck(list_settings, "height_mm")


#----------------------------------------------------------#
# 1. Icons -----
#----------------------------------------------------------#

dir_icons <-
  base::file.path(base::tempdir(), "extraction_workflow_icons")

# Dataset types in the colours of the website, functions in black
data_icons <-
  tibble::tribble(
    ~icon_id, ~icon, ~colour,
    "r", "r-project", "blue_light",
    "vegetation_plot", "seedling", "green_light",
    "fossil_pollen_archive", "layer-group", "purple_light",
    "traits", "leaf", "blue_dark",
    "gridpoints", "cloud-sun", "green_dark",
    "geo", "earth-americas", "black",
    "age", "hourglass-half", "black",
    "data", "table", "black",
    "references", "book-open", "black"
  ) |>
  dplyr::mutate(
    path = purrr::pmap_chr(
      .l = base::list(icon_id, icon, colour),
      .f = ~ save_icon_png(
        icon = ..2,
        fill = purrr::chuck(list_colors, ..3),
        path_output = base::file.path(dir_icons, stringr::str_c(..1, ".png"))
      )
    )
  )

vec_icon_paths <-
  data_icons |>
  dplyr::select("icon_id", "path") |>
  tibble::deframe()


#----------------------------------------------------------#
# 2. Layout -----
#----------------------------------------------------------#

# Steps 3 to 6: a question box on the left, the functions on a panel to
#   its right; the panels are listed first, so the boxes cover their edge
vec_y_steps <- c(132, 96, 60, 24)

data_boxes <-
  dplyr::bind_rows(
    tibble::tribble(
      ~x, ~y, ~width, ~height, ~fill, ~colour,
      # Panels under the database and the package
      46, 182.5, 64, 23, "white", NA,
      134, 182.5, 76, 23, "white", NA,
      # Boxes of the database and the package
      46, 209, 80, 30, "beige_light", "black",
      134, 209, 80, 30, "beige_light", "black",
      # The R session
      90, 160, 168, 9, "white", NA
    ),
    tibble::tibble(
      x = 120, y = vec_y_steps, width = 108, height = 26,
      fill = "white", colour = NA
    ),
    tibble::tibble(
      x = 38, y = vec_y_steps, width = 64, height = 30,
      fill = "beige_light", colour = "black"
    )
  )

data_links <-
  tibble::tribble(
    ~x, ~y, ~xend, ~yend,
    46, 171, 38, 147,
    134, 171, 38, 147,
    38, 117, 38, 111,
    38, 81, 38, 75,
    38, 45, 38, 39
  )

data_numbers <-
  tibble::tibble(
    x = c(15, 103, 15, 15, 15, 15),
    y = c(209, 209, vec_y_steps),
    label = base::as.character(1:6)
  )

data_images <-
  tibble::tribble(
    ~x, ~y, ~path, ~size,
    33, 209, here::here("Outputs/Figures/website/VegVault_logo.png"), 0.133,
    121, 209, here::here("Data/Website/Logos/vaultkeepr.png"), 0.111,
    14, 160, vec_icon_paths[["r"]], 0.05,
    # Step 3: dataset types
    80, 132, vec_icon_paths[["vegetation_plot"]], 0.033,
    80, 124, vec_icon_paths[["fossil_pollen_archive"]], 0.033,
    136, 132, vec_icon_paths[["traits"]], 0.033,
    136, 124, vec_icon_paths[["gridpoints"]], 0.033,
    # Step 4: space and time
    136, 103, vec_icon_paths[["geo"]], 0.033,
    136, 89, vec_icon_paths[["age"]], 0.033,
    # Step 5: attributes
    136, 67, vec_icon_paths[["vegetation_plot"]], 0.033,
    144, 67, vec_icon_paths[["fossil_pollen_archive"]], 0.033,
    136, 60, vec_icon_paths[["traits"]], 0.033,
    136, 53, vec_icon_paths[["gridpoints"]], 0.033,
    # Step 6: data and references
    136, 28, vec_icon_paths[["data"]], 0.033,
    136, 20, vec_icon_paths[["references"]], 0.033
  )

text_doi <-
  stringr::str_c(
    "DOI: ",
    stringr::str_replace(purrr::chuck(list_settings, "doi"), "/", "/\n")
  )

data_texts <-
  tibble::tribble(
    ~x, ~y, ~label, ~size, ~font, ~fontface, ~hjust,
    # 1: the database
    65, 216, "Get the", 5.5, "text", "plain", 0.5,
    65, 209, "VegVault", 6.5, "text", "bold", 0.5,
    65, 202, "database", 5.5, "text", "plain", 0.5,
    46, 182.5, text_doi, 4.2, "code", "plain", 0.5,
    # 2: the package
    152, 216, "Get the", 5.5, "text", "plain", 0.5,
    152, 209, "{vaultkeepr}", 5.2, "text", "bold", 0.5,
    152, 202, "R package", 5.5, "text", "plain", 0.5,
    99, 182.5,
    "remotes::install_github(\n  \"OndrejMottl/vaultkeepr\"\n)",
    4, "code", "plain", 0,
    # The R session
    22, 160, "open_vault(path = \"<path_to_VegVault>\") %>% get_datasets()",
    4, "code", "plain", 0,
    # 3: dataset types
    46, 132, "Which types of\ndataset to use?", 5.2, "text", "plain", 0.5,
    76, 140, "select_dataset_by_type()", 4.2, "code", "bold", 0,
    85, 132, "vegetation_plot", 3.8, "code", "italic", 0,
    85, 124, "fossil_pollen_archive", 3.8, "code", "italic", 0,
    141, 132, "traits", 3.8, "code", "italic", 0,
    141, 124, "gridpoints", 3.8, "code", "italic", 0,
    # 4: space and time
    46, 96, "Which area and\ntime period?", 5.2, "text", "plain", 0.5,
    76, 103, "select_dataset_by_geo()", 4.2, "code", "bold", 0,
    76, 96, "get_samples()", 4.2, "code", "bold", 0,
    76, 89, "select_samples_by_age()", 4.2, "code", "bold", 0,
    141, 103, "lat_lim\nlong_lim", 3.8, "code", "plain", 0,
    141, 89, "age_lim", 3.8, "code", "plain", 0,
    # 5: attributes
    46, 60, "Which attributes\nto include?", 5.2, "text", "plain", 0.5,
    76, 67, "get_taxa()", 4.2, "code", "bold", 0,
    76, 60, "get_traits()", 4.2, "code", "bold", 0,
    76, 53, "get_abiotic_data()", 4.2, "code", "bold", 0,
    # 6: extraction
    46, 24, "Extract the data\nand references", 5.2, "text", "plain", 0.5,
    76, 28, "extract_data()", 4.2, "code", "bold", 0,
    76, 20, "get_references()", 4.2, "code", "bold", 0,
    # Credit of the icons
    174, 3, "Icons: Font Awesome Free (CC BY 4.0)", 2.8, "text", "plain", 1
  ) |>
  dplyr::mutate(colour = "black")


#----------------------------------------------------------#
# 3. Draw and save -----
#----------------------------------------------------------#

plot_extraction <-
  plot_diagram(
    data_boxes = data_boxes,
    data_texts = data_texts,
    data_images = data_images,
    data_links = data_links,
    data_numbers = data_numbers,
    list_colors = list_colors,
    list_fonts = list_fonts,
    x_lim = c(0, width_mm),
    y_lim = c(0, height_mm),
    color_background = purrr::chuck(list_settings, "background")
  )

ggplot2::ggsave(
  filename = here::here(purrr::chuck(list_settings, "file")),
  plot = plot_extraction,
  width = width_mm,
  height = height_mm,
  units = "mm",
  dpi = purrr::chuck(list_settings, "dpi"),
  bg = purrr::chuck(list_colors, purrr::chuck(list_settings, "background"))
)
