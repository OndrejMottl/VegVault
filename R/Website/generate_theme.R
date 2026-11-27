# Generate Dynamic Theme Files
# Run this script to update _colors.scss, _fonts.scss and _topics.scss from
#   JSON files

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
        # A tag: slim, so that it does not reach into the next line, and
        #   whole on each line when it breaks
        ".text-background-", .y, " {\n",
        "background-color: ", unname(.x), ";\n",
        "padding: 0.08em 0.38em;\n",
        "border-radius: 0.35em;\n",
        "-webkit-box-decoration-break: clone;\n",
        "box-decoration-break: clone;\n",
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
    "// Import Google Fonts\n@import url('https://fonts.googleapis.com/css2?family=Press+Start+2P&family=Inter:wght@300;400;500;600;700&display=swap');\n",
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

# Topics of headings: the colour of the bar and the icon of the tile
#   (_text_highlights.scss), from topics.json, with colour names of
#   colors.json and icons of Font Awesome Free (the fontawesome package)
topics <-
  jsonlite::fromJSON(
    here::here("topics.json")
  )

topics_definition <-
  purrr::imap(
    .x = topics,
    .f = ~ {
      # SVG takes #RRGGBB; colors.json may add an alpha value
      icon_fill <-
        substr(colors[[.x$icon_color]], 1, 7)

      icon_svg <-
        as.character(
          fontawesome::fa(
            name = .x$icon,
            fill = icon_fill,
            prefer_type = "solid"
          )
        )

      icon_svg <-
        sub(
          "<svg ",
          paste0(
            "<svg xmlns=\"http://www.w3.org/2000/svg\" fill=\"",
            icon_fill, "\" "
          ),
          icon_svg
        )

      icon_svg <-
        sub(" style=\"[^\"]*\"", "", icon_svg)

      # One line: a line break inside url() would break the rule
      icon_base64 <-
        gsub("\\s", "", jsonlite::base64_enc(charToRaw(icon_svg)))

      paste0(
        ".topic-", .y, " {\n",
        "--topic-color: ", unname(colors[[.x$color]]), ";\n",
        "--topic-icon: url(\"data:image/svg+xml;base64,", icon_base64,
        "\");\n",
        " }", "\n"
      )
    }
  ) %>%
  paste(collapse = "\n")

writeLines(
  text = c(
    "// This file is auto-generated from topics.json. Do not edit directly.",
    paste0(
      "/*! Icons: Font Awesome Free ",
      fontawesome::fa_metadata()$version,
      " by @fontawesome - https://fontawesome.com",
      " License - https://fontawesome.com/license/free",
      " (Icons: CC BY 4.0) */"
    ),
    topics_definition
  ),
  con = here::here("_topics.scss")
)
