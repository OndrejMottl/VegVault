# Generate Dynamic Theme Files
# Run this script to update _colors.scss and _fonts.scss from JSON files

# Install and load required packages
if (!require("jsonlite")) install.packages("jsonlite")
if (!require("here")) install.packages("here")
if (!require("purrr")) install.packages("purrr")

library(jsonlite)
library(here)
library(purrr)

# Colors
colors <-
  jsonlite::fromJSON(
    here::here("colors.json")
  )

colors_definition <-
  purrr::imap(
    .x = colors,
    .f = ~ {
      paste0(
        "$", .y, ": ", unname(.x), ";", "\n",
        ".bg-", .y, " { background-color: ", unname(.x), "; }\n",
        ".text-color-", .y, " { color: ", unname(.x), " !important ; }\n",
        ".text-background-", .y, " {\n",
        "background-color: ", unname(.x), ";\n",
        "padding: $smallMargin;\n",
        "border-radius: 5px;\n",
        " }", "\n"
      )
    }
  ) %>%
  paste(collapse = "\n")

writeLines(
  text = c(
    "// This file is auto-generated from colors.json. Do not edit directly.",
    colors_definition
  ),
  con = here::here("_colors.scss")
)

# Fonts
fonts <-
  jsonlite::fromJSON(
    here::here("fonts.json")
  )

fonts_definition <-
  c(
    paste0('$mainFont: "', fonts$body, '", "Arial", sans-serif !default;\n'),
    paste0('$headingFont: "', fonts$heading, '", "Courier New", monospace !default;\n'),
    paste0(
      ".text-font-body { font-family: $mainFont; }\n",
      ".text-font-heading { font-family: $headingFont; }\n"
    ),
    paste0(
      "/* Debug font loading - this will help us see if the font is loaded */\n",
      "@supports (font-family: \"", fonts$heading, "\") {\n",
      "  .debug-font-loaded::before {\n",
      "    content: \"", fonts$heading, " font is supported\";\n",
      "    display: block;\n",
      "    font-size: 12px;\n",
      "    color: green;\n",
      "  }\n",
      "}\n\n",
      "/* Force font loading for debugging */\n",
      ".force-press-start {\n",
      "  font-family: \"", fonts$heading, "\", monospace !important;\n",
      "  font-display: swap;\n",
      "}\n"
    )
  )

writeLines(
  text = c(
    "// This file is auto-generated from fonts.json. Do not edit directly.",
    fonts_definition
  ),
  con = here::here("_fonts.scss")
)
