# Logos of the workflow figures

The logos in the figures of the data assembly (`R/Website/render_assembly_workflow.R`) and of the data extraction (`R/Website/render_extraction_workflow.R`) on the website, as PNG files of at most 800 px width. The logos of the data sources belong to their projects and are used here only to name the sources.

- `neotoma.png`: Neotoma Paleoecology Database; drawn at 800 px from the vector logo in Neotoma's own workshop slides, downloaded on 2026-11-25 from <https://github.com/NeotomaDB/Workshops> (`2022_EPD/slides/img/logo.svg`).
- `splotopen.png`: sPlotOpen; taken from the earlier hand-made figure (`Outputs/Figures/DB_assembly_visualisation/assembly_viz_03.svg`, removed with the move to the figure drawn in code and kept in the git history), because the iDiv website could not be reached on 2026-11-25 and no other copy was found online.
- `bien.png`: Botanical Information and Ecology Network; downloaded on 2026-11-25 from <https://bien.nceas.ucsb.edu/bien/wp-content/uploads/2021/01/FinalBIENLogoNoText_highres.png> and scaled down.
- `try.png`: TRY Plant Trait Database; taken from the earlier figure (neither the TRY website nor a web search gave a logo file) and converted from JPEG.
- `chelsa.png`: CHELSA climate data; taken from the earlier figure, identical to <https://chelsa-climate.org/static/chelsa_logo.gif>, and scaled down.
- `fossilpol.png`: FOSSILPOL workflow; downloaded on 2026-11-25 from the FOSSILPOL website repository (<https://github.com/HOPE-UIB-BIO/FOSSILPOL-website>, `docs/en/figures/Logo FOSSILPOL regular - 600ppi.png`) and scaled down.

- `vaultkeepr.png`: the {vaultkeepr} R package; copied from the package repository (<https://github.com/OndrejMottl/vaultkeepr>, `man/figures/vaultkeeper_logo.png`, commit `367f0ce`).

The Harmonized World Soil Database has no logo of its own, and its technical report does not permit use of the FAO logo, so the figure names it in text. The VegVault logo is the one of the website, `Outputs/Figures/website/VegVault_logo.png`.

The icons of the extraction figure (the R logo, the dataset types and the steps) are not stored here: the script draws them from Font Awesome Free, bundled with the `fontawesome` R package, which is licensed under CC BY 4.0 and credited in the figure.
