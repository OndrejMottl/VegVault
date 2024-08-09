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

## Example 1

In the first example, we can imagine a scenario, where we are interested
in spatiotemporal patterns of the *Picea* genus across North America for
modern data and since the Last Glacial Maximum. Obtaining such data is
straightforward:

``` r
# First create a plan
plan_na_plots_picea <-
  # Access the VegVault
  vaultkeepr::open_vault(
    path = paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  ) %>%
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
  # Add taxa
  vaultkeepr::get_taxa(
    # Classify all data to a genus level
    classify_to = "genus"
  ) %>%
  # Extract only Picea data
  vaultkeepr::select_taxa_by_name(sel_taxa = c("Picea"))

# Execute the plan
data_na_plots_picea <-
  vaultkeepr::extract_data(plan_na_plots_picea)
```

Now, we plot the presence of *Picea* in each 2500-year bin.

<img src="figures/Example%201%20-%20plot%20distribution-1.png"
style="width:100.0%" data-fig-align="center" />

## Example 2

In the second example, let’s imagine we want to do Species Distribution
Modeling for all plant taxa in the Czech Republic. We will extract
modern plot-based data and Mean Annual temprature.

``` r
# Again start by creating a plan
plan_cz_modern <-
  # Acess the VegVault file
  vaultkeepr::open_vault(
    path = paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  ) %>%
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
  vaultkeepr::get_abiotic() %>%
  # Select only Mean Anual Temperature (bio1)
  vaultkeepr::select_abiotic_var_by_name(
    sel_var_name = "bio1"
  ) %>%
  # add taxa
  vaultkeepr::get_taxa()

# Execute the plan
data_cz_modern <-
  vaultkeepr::extract_data(plan_cz_modern)
```

Now we can simply plot both the climatic data and the plot vegetation
data:

<img src="figures/Example%202%20-%20plot-1.png" style="width:100.0%"
data-fig-align="center" />

## Example 3

In the last example, let’s imagine we want to reconstruct the Community
Weighted Mean (CWM) of plant height for Latin America between 6-12 ka yr
BP.

``` r
# Again start by creating a plan
plan_la_traits <-
  # Acess the VegVault file
  vaultkeepr::open_vault(
    path = paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  ) %>%
  # Add the dataset information
  vaultkeepr::get_datasets() %>%
  # Select modern plot data and climate
  vaultkeepr::select_dataset_by_type(
    sel_dataset_type = c(
      "fossil_pollen_archive",
      "traits"
    )
  ) %>%
  # Limit data to Latin America
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
  # add taxa
  vaultkeepr::get_taxa(
    # Clasify all data to a genus level
    classify_to = "genus"
  ) %>%
  # add trait information
  vaultkeepr::get_traits(
    # Clasify all data to a genus level
    classify_to = "genus"
  ) %>%
  # Only select the plant height
  vaultkeepr::select_traits_by_domain_name(
    sel_domain = "Plant heigh"
  )

# Execute the plan
data_la_traits <-
  vaultkeepr::extract_data(plan_la_traits)
```

Now let’s plot the overview of the data

<img src="figures/Example%203%20-%20plot-1.png" style="width:100.0%"
data-fig-align="center" />
