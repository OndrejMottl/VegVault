#----------------------------------------------------------#
#
#
#                       VegVault
#
#                  render "." quarto files
#
#
#                       O. Mottl
#                         2023
#
#----------------------------------------------------------#

# Script to render all .*.qmd files (which are very slow to render) to .md files
#   to selectively render them only when needed
#   and not when the project is built

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

render_md <- function(
    file_name,
    file_dir = "website/database_structure",
    output_dir = "docs/website/database_structure",
    copy = TRUE) {
  require(quarto)

  quarto::quarto_render(
    input = here::here(
      file_dir,
      paste0(file_name, ".qmd")
    ),
    output_format = "md"
  )

  if (
    isTRUE(copy)
  ) {
    fs::file_copy(
      path = here::here(
        output_dir,
        paste0(file_name, ".md")
      ),
      new_path = here::here(
        file_dir,
        paste0(file_name, ".md")
      ),
      overwrite = TRUE
    )

    fs::file_delete(
      here::here(
        output_dir,
        paste0(file_name, ".md")
      )
    )
  }
}

#----------------------------------------------------------#
#  1. Render sections -----
#----------------------------------------------------------#

render_md("_01_Description_of_VegVault")

render_md("_02_Datasets")

render_md("_03_Samples")

render_md("_04_Taxa")

render_md("_05_Traits")

render_md("_06_Abiotic")

render_md(
  file_name = "_database_examples",
  file_dir = "website",
  copy = FALSE
)
