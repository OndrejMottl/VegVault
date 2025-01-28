save_figure_to_render <- function(
    sel_plot,
    image_width = 2450, # [config]
    image_height = 1200, # [config]
    image_unit = "px" # [config]
    ) {
  file_name <-
    substitute(sel_plot) %>%
    deparse()

  ggplot2::ggsave(
    here::here(
      "Outputs/Figures/website/DB_structure",
      paste0(
        file_name,
        ".png"
      )
    ),
    plot = sel_plot,
    width = image_width,
    height = image_height,
    units = image_units,
    bg = col_beige_light # [config]
  )

  include_graphics_absolute_path(
    here::here(
      "Outputs/Figures/website/DB_structure",
      paste0(
        file_name,
        ".png"
      )
    )
  )
}
