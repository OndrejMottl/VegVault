# Section IV: Examples of usage


The **VegVault** database can be accessed via our newly developed
[{vaultkeepr} R-package](https://github.com/OndrejMottl/vaultkeepr),
which provides a series of easy-to-use functions in [R programming
language](https://en.wikipedia.org/wiki/R_(programming_language)).

The {vaultkeepr} can be installed from [GitHub](https://github.com/)
with:

``` r
# install.packages("remotes")
remotes::install_github("OndrejMottl/vaultkeepr")
```

and then all functions will be made available by attaching as:

``` r
library(vaultkeepr)
```

## Example 1: Spatiotemporal patterns of the Picea genus across North America since the LGM

In the first example, we can imagine a scenario, where we are interested
in spatiotemporal patterns of the *Picea* genus across North America for
modern data and since the Last Glacial Maximum. Obtaining such data is
straightforward:

``` r
data_na_plots_picea <-
  # Access the VegVault
  vaultkeepr::open_vault(path = "<path_to_VegVault>") %>%
  # Start by adding dataset information
  vaultkeepr::get_datasets() %>%
  # Select both modern and paleo plot data
  vaultkeepr::select_dataset_by_type(
    sel_dataset_type = c(
      "vegetation_plot",
      "fossil_pollen_archive"
    )
  ) %>%
  # Limit data to North America
  vaultkeepr::select_dataset_by_geo(
    lat_lim = c(22, 60),
    long_lim = c(-135, -60)
  ) %>%
  # Add samples
  vaultkeepr::get_samples() %>%
  # Limit the samples by age
  vaultkeepr::select_samples_by_age(
    age_lim = c(0, 15e3)
  ) %>%
  # Add taxa & classify all data to a genus level
  vaultkeepr::get_taxa( classify_to = "genus") %>%
  # Extract only Picea data
  vaultkeepr::select_taxa_by_name(sel_taxa = "Picea") %>%
  vaultkeepr::extract_data()
```

Now, we plot the presence of *Picea* in each 2500-year bin.

<img src="../Figures/fig_na_plots_picea.png" style="width:100.0%"
data-fig-align="center" />

## Example 2: Joined Species Distribution model for all vegetation within Czechia

In the second example, let’s imagine we want to do Species Distribution
Modeling for all plant taxa in the Czech Republic. We will extract
modern plot-based data and Mean Annual temprature.

``` r
data_cz_modern <-
  # Acess the VegVault file
  vaultkeepr::open_vault(path = "<path_to_VegVault>") %>%
  # Add the dataset information
  vaultkeepr::get_datasets() %>%
  # Select modern plot data and climate
  vaultkeepr::select_dataset_by_type(
    sel_dataset_type = c(
      "vegetation_plot",
      "gridpoints"
    )
  ) %>%
  # Limit data to Czech Republic
  vaultkeepr::select_dataset_by_geo(
    lat_lim = c(48.5, 51.1),
    long_lim = c(12, 18.9)
  ) %>%
  # Add samples
  vaultkeepr::get_samples() %>%
  # select only modern data
  vaultkeepr::select_samples_by_age(
    age_lim = c(0, 0)
  ) %>%
  # Add abiotic data
  vaultkeepr::get_abiotic_data() %>%
  # Select only Mean Anual Temperature (bio1)
  vaultkeepr::select_abiotic_var_by_name(sel_var_name = "bio1") %>%
  # add taxa
  vaultkeepr::get_taxa() %>%
  vaultkeepr::extract_data()
```

Now we can simply plot both the climatic data and the plot vegetation
data:

<img src="../Figures/fig_cz_jsdm.png" style="width:100.0%"
data-fig-align="center" />

## Example 3: Patterns of plant height (CWM) for South and Central Latin America between 6-12 ka

In the last example, let’s imagine we want to reconstruct the Community
Weighted Mean (CWM) of plant height for Latin America between 6-12 ka yr
BP.

``` r
data_la_traits <-
  # Acess the VegVault file
  vaultkeepr::open_vault(path = "<path_to_VegVault>") %>%
  # Add the dataset information
  vaultkeepr::get_datasets() %>%
  # Select modern plot data and climate
  vaultkeepr::select_dataset_by_type(
    sel_dataset_type = c(
      "fossil_pollen_archive",
      "traits"
    )
  ) %>%
  # Limit data to South and Central America
  vaultkeepr::select_dataset_by_geo(
    lat_lim = c(-53, 28),
    long_lim = c(-110, -38),
    sel_dataset_type = c(
      "fossil_pollen_archive",
      "traits"
    )
  ) %>%
  # Add samples
  vaultkeepr::get_samples() %>%
  # Limit to 6-12 ka yr BP
  vaultkeepr::select_samples_by_age(
    age_lim = c(6e3, 12e3)
  ) %>%
  # add taxa & clasify all data to a genus level
  vaultkeepr::get_taxa(classify_to = "genus") %>%
  # add trait information & clasify all data to a genus level
  vaultkeepr::get_traits(classify_to = "genus") %>%
  # Only select the plant height
  vaultkeepr::select_traits_by_domain_name(sel_domain = "Plant heigh") %>%
  vaultkeepr::extract_data()
```

Now let’s plot the overview of the data

<img src="../Figures/fig_la_merge.png" style="width:100.0%"
data-fig-align="center" />
