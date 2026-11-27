

<!-- README.md is generated from README.qmd. Please edit that file -->

# VegVault database <img src="Outputs/Figures/website/VegVault_logo.png" align="right" width="200"/>

<!-- badges: start -->

[![Version](https://img.shields.io/github/v/release/OndrejMottl/VegVault?label=Version&logo=github)](https://github.com/OndrejMottl/VegVault/releases)
[![Data paper](https://img.shields.io/badge/Data%20paper-10.1038%2Fs41597--025--06176--1-blue)](https://doi.org/10.1038/s41597-025-06176-1)
<!-- badges: end -->

VegVault is an open database that links global fossil pollen records and present-day vegetation plots with plant functional traits and with the climate and soil of each sample’s place and time.
By bringing past and present vegetation data into one place, it supports research on long-term vegetation change and on how vegetation responds to climate.
It is described in the [VegVault data paper](https://doi.org/10.1038/s41597-025-06176-1) in *Scientific Data*, and its [website](https://bit.ly/VegVault) documents the content, structure and use of the database.
VegVault is part of the [BIODYNAMICS project](https://ondrejmottl.github.io/projects/BIODYNAMICS/).

## What is in VegVault 2.0.0

| Data | Sources |
|----|----|
| Fossil pollen records | [Neotoma Paleoecology Database](https://www.neotomadb.org/), processed with the [FOSSILPOL](https://bit.ly/FOSSILPOL) workflow |
| Vegetation plots | [sPlotOpen](https://idiv-biodiversity.de/en/splot/splotopen.html) and the [Botanical Information and Ecology Network (BIEN)](https://bien.nceas.ucsb.edu/bien/) |
| Plant functional traits | [TRY Plant Trait Database](https://www.try-db.org/) and BIEN |
| Climate | [CHELSA](https://chelsa-climate.org/) V2.1 for the present day and CHELSA-TraCE21k for the past |
| Soil | [Harmonized World Soil Database (HWSD)](https://data.apps.fao.org/catalog/iso/ff5c613c-75bb-46a9-a162-bc728059b465) |

The release 2.0.0 holds:

- 1,551 fossil pollen records and 91,183 vegetation plots;
- 12,459,714 samples of plots, pollen records, trait measurements and gridpoints, with ages from the present day back to 19,994 calibrated years before present;
- 109,220 taxon names, classified to species, genus and family;
- 10,920,952 trait values in 6 trait domains, from 222,455 trait datasets;
- 8 climate and soil variables at 106,415 gridpoints, each linked to the samples within 50 km and 5,000 years of it.

The [Database Content](https://ondrejmottl.github.io/VegVault/website/database_content.html) and [Database Assembly](https://ondrejmottl.github.io/VegVault/website/database_assembly.html) pages of the website give the details, including the version of each source.

## Get the data

VegVault is one SQLite file of 6.5 GB, deposited in the [EOSC CZ data repository](https://datarepo.eosc.cz/) together with a copy of its tables as flat files: [the database](https://doi.org/10.48700/frrj8-ync93) and [the flat files](https://doi.org/10.48700/qwdh2-qh173).
These two DOIs always lead to the newest version; the [changelog](https://ondrejmottl.github.io/VegVault/website/database_changelog.html) of the website gives the DOI of each version, and the [Database Access](https://ondrejmottl.github.io/VegVault/website/database_access.html) page describes the files.
We recommend the SQLite file with the R package vaultkeepr.

## Use it with vaultkeepr

[vaultkeepr](https://github.com/OndrejMottl/vaultkeepr) opens the database read-only and extracts only the data you select, so the whole database never has to fit in memory.

``` r
# install.packages("remotes")
remotes::install_github("OndrejMottl/vaultkeepr")

library(vaultkeepr)

# Climate of the present-day vegetation plots of a region, from the
#   gridpoint nearest to each plot
data_plots_climate <-
  open_vault(path = "path/to/VegVault.sqlite") |>
  get_datasets() |>
  select_dataset_by_type(
    sel_dataset_type = c("vegetation_plot", "gridpoints")
  ) |>
  select_dataset_by_geo(
    long_lim = c(14, 16),
    lat_lim = c(44, 46)
  ) |>
  get_samples() |>
  select_samples_by_age(
    age_lim = c(0, 0),
    sel_dataset_type = "vegetation_plot"
  ) |>
  get_abiotic_data() |>
  extract_data()
```

The [Examples of usage](https://ondrejmottl.github.io/VegVault/website/database_examples.html) page of the website and the [vaultkeepr articles](https://ondrejmottl.github.io/vaultkeepr/) show more workflows: taxa classified to genus or family, plant traits, references to cite and the age uncertainty of fossil pollen samples.

## Versions

Every database file records its version in its `version_control` table.
The [changelog](https://ondrejmottl.github.io/VegVault/website/database_changelog.html) on the website lists every version and what changed between releases, and the [releases](https://github.com/OndrejMottl/VegVault/releases) of this repository hold the code of each release.

## How to cite

When you use VegVault, cite the version you used (its DOI is on the [Database Access](https://ondrejmottl.github.io/VegVault/website/database_access.html) page), the [VegVault data paper](https://doi.org/10.1038/s41597-025-06176-1) and the original data sources.
The vaultkeepr function `get_references()` lists the references of a selection and marks those that must be cited.

## Licences

The code of this repository is under the [MIT License](LICENSE).
The database is released under [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/), and its data keep the licences of their sources: Neotoma, sPlotOpen and HWSD under CC BY 4.0, BIEN and TRY public data under CC BY, CHELSA V2.1 under CC0 1.0 and CHELSA-TraCE21k with attribution required.

## This repository

The R code here builds VegVault as one SQLite file from tagged releases of four data repositories, and holds the website:

- [VegVault-Vegetation_data](https://github.com/OndrejMottl/VegVault-Vegetation_data): sPlotOpen and BIEN vegetation plots;
- [VegVault-FOSSILPOL](https://github.com/OndrejMottl/VegVault-FOSSILPOL): fossil pollen records from Neotoma;
- [VegVault-Trait_data](https://github.com/OndrejMottl/VegVault-Trait_data): TRY and BIEN plant traits;
- [VegVault-abiotic_data](https://github.com/OndrejMottl/VegVault-abiotic_data): CHELSA climate and HWSD soil.

The build classifies the taxa, links every sample to the climate and soil of the gridpoints near it in space and time, checks the result and exports the flat files.

## Contact and contributing

Questions and suggestions are welcome through the [issues](https://github.com/OndrejMottl/VegVault/issues) of this repository or the [contact page](https://ondrejmottl.github.io/VegVault/website/contact.html) of the website.
The [Contribute](https://ondrejmottl.github.io/VegVault/website/contribute.html) page says how to take part.
