#----------------------------------------------------------#
#
#
#                       VegVault
#
#              Schema diagrams of the website
#
#
#                       O. Mottl
#                         2026
#
#----------------------------------------------------------#
# Draws the schema diagrams of the website from the DBML mirror of the
#   schema (Data/SQL/database_structure.dbml) with dbml-renderer, in the
#   colours of the website: the full diagram and one diagram per table
#   section, as set in `website: schema_diagrams` of config.yml. Existing
#   diagrams are replaced. Needs Node.js; npx downloads the pinned renderer
#   on the first run. Run from the repository root:
#
#   Rscript R/Website/render_schema_diagrams.R


#----------------------------------------------------------#
# 0. Setup -----
#----------------------------------------------------------#

library(here)

source(
  here::here("R/___setup_project___.R")
)

list_settings <-
  load_config_value(value = c("website", "schema_diagrams"))

list_dbml_structure <-
  load_dbml_structure(
    path_dbml = here::here("Data", "SQL", "database_structure.dbml")
  )

list_colors <-
  load_figure_colors(path_colors = here::here("colors.json"))

list_theme_settings <-
  purrr::chuck(list_settings, "theme")

# The theme names colours of colors.json, which may carry an alpha value;
#   the SVG takes #RRGGBB
list_theme <-
  c(
    purrr::map(
      .x = list_theme_settings[c("header", "body", "text", "line")],
      .f = ~ stringr::str_sub(
        purrr::chuck(list_colors, .x),
        start = 1L,
        end = 7L
      )
    ),
    base::list(font = purrr::chuck(list_theme_settings, "font"))
  )

path_npx <-
  base::Sys.which("npx")

# Header colours of the tables, section by section; the header text stays
#   white
data_table_colors <-
  list_settings |>
  purrr::chuck("sections") |>
  purrr::map(
    .f = ~ tibble::tibble(
      table_name = base::unlist(purrr::chuck(.x, "tables")),
      fill = stringr::str_sub(
        purrr::chuck(list_colors, purrr::chuck(.x, "colour")),
        start = 1L,
        end = 7L
      ),
      text = "#ffffff"
    )
  ) |>
  dplyr::bind_rows()


#----------------------------------------------------------#
# 1. Diagrams to draw -----
#----------------------------------------------------------#

# The full diagram holds every table in the order of the DBML file
vec_tables_all <-
  list_dbml_structure |>
  purrr::chuck("columns") |>
  dplyr::pull(table_name) |>
  base::unique()

list_figures <-
  purrr::chuck(list_settings, "figures")

data_diagrams <-
  tibble::tibble(
    path_output = c(
      here::here(purrr::chuck(list_settings, "full_diagram")),
      here::here(
        purrr::chuck(list_settings, "output_dir"),
        stringr::str_c(base::names(list_figures), ".svg")
      )
    ),
    list_tables = c(
      base::list(vec_tables_all),
      purrr::map(
        .x = list_figures,
        .f = ~ select_linked_tables(
          list_dbml_structure = list_dbml_structure,
          vec_tables = base::unlist(.x)
        )
      )
    )
  )


#----------------------------------------------------------#
# 2. Draw -----
#----------------------------------------------------------#

purrr::walk2(
  .x = dplyr::pull(data_diagrams, list_tables),
  .y = dplyr::pull(data_diagrams, path_output),
  .f = ~ render_schema_diagram(
    text_dbml = build_dbml_text(
      list_dbml_structure = list_dbml_structure,
      vec_tables = .x
    ),
    path_output = .y,
    list_theme = list_theme,
    renderer = purrr::chuck(list_settings, "renderer"),
    path_npx = path_npx,
    data_table_colors = data_table_colors
  ),
  .progress = TRUE
)
