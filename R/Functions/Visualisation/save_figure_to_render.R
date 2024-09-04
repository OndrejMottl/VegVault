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
      paste(
        "Figures/",
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

  knitr::include_graphics(
    here::here(
      paste(
        "Figures/",
        file_name,
        ".png"
      )
    )
  )
}
