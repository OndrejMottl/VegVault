save_mns_figure <- function(
    sel_plot,
    image_width,
    image_height) {
  file_name <-
    substitute(sel_plot) %>%
    deparse() %>%
    stringr::str_remove_all(" ")

  ggplot2::ggsave(
    here::here(
      paste0(
        "Outputs/Figures/mns/",
        file_name,
        ".pdf"
      )
    ),
    plot = sel_plot,
    width = image_width,
    height = image_height,
    units = image_units, # [config]
    bg = col_white # [config]
  )
}
