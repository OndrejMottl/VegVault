# Section IV: Examples of usage


## Example 1

In the first example, we can imagine a scenario, where we are interested
in spatiotemporal patterns of the *Picea* genus across North America for
modern data and since the Last Glacial Maximum. Obtaining such data is
straightforward:

``` r
# First create a plan
plan_na_plots_picea <-
  # Access the VegVault
  open_vault(
    path = paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  ) %>%
  # Start by adding dataset information
  get_datasets() %>%
  # Select both modern and paleo plot data
  select_dataset_by_type(
    sel_type = c(
      "vegetation_plot",
      "fossil_pollen_archive"
    )
  ) %>%
  # Limit data to North America
  select_dataset_by_geo(
    lat_lim = c(22, 60),
    long_lim = c(-135, -60)
  ) %>%
  # Add samples
  get_samples() %>%
  # Limit the samples by age
  select_samples_by_age(
    age_lim = c(0, 15e3)
  ) %>%
  # Add taxa
  get_taxa() %>%
  # Harmonise all data to a genus level
  harmonise_taxa(to = "genus") %>%
  # Extract only Picea data
  select_taxa(sel_taxa = c("Picea"))

# Execute the plan
data_na_plots_picea <-
  extract_data(plan_na_plots_picea)
```

Now, we plot the presence of *Picea* in each 2500-year bin.

<img src="figures/Example%201%20-%20plot%20distribution-1.png"
style="width:100.0%" data-fig-align="center" />

## Example 2

In the second example, let’s imagine we want to do Joined - Species
Distribution Modeling for all plant taxa in the Czech Republic. We will
extract modern plot-based data and climate.

``` r
# Again start by creating a plan
plan_cz_modern <-
  # Acess the VegVault file
  open_vault(
    path = paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  ) %>%
  # Add the dataset information
  get_datasets() %>%
  # Select modern plot data and climate
  select_dataset_by_type(
    sel_type = c(
      "vegetation_plot",
      "gridpoints"
    )
  ) %>%
  # Limit data to Czech Republic
  select_dataset_by_geo(
    lat_lim = c(48.5, 51.1),
    long_lim = c(12, 18.9)
  ) %>%
  # Add samples
  get_samples() %>%
  # Now it is a good idea to make sure to only keep modern data
  select_samples_by_age(
    age_lim = c(0, 0)
  ) %>%
  # Add abiotic data
  get_abiotic() %>%
  # Select only Mean Anual Temperature (bio1)
  select_abiotic_by_var(
    sel_var = c("bio1")
  ) %>%
  # add taxa
  get_taxa()

# Execute the plan
data_cz_modern <-
  extract_data(plan_cz_modern)
```

Now we can simply plot both the climatic data and the plot vegetation
data:

<img src="figures/Example%202%20-%20plot-1.png" style="width:100.0%"
data-fig-align="center" />

## Example 3

In the last example, let’s imagine we want to recostruct the Community
Weighted Mean (CWM) of plant heigh for Latin America between 6-12 ka yr
BP.

``` r
# Again start by creating a plan
plan_la_traits <-
  # Acess the VegVault file
  open_vault(
    path = paste0(
      data_storage_path,
      "Data/VegVault/VegVault.sqlite"
    )
  ) %>%
  # Add the dataset information
  get_datasets() %>%
  # Select modern plot data and climate
  select_dataset_by_type(
    sel_type = c(
      "fossil_pollen_archive",
      "traits"
    )
  ) %>%
  # Limit data to Latin America
  select_dataset_by_geo(
    lat_lim = c(-53, 28),
    long_lim = c(-110, -38)
  ) %>%
  # Add samples
  get_samples() %>%
  # Limit to 6-12 ka yr BP
  select_samples_by_age(
    age_lim = c(6e3, 12e3)
  ) %>%
  # add taxa
  get_taxa() %>%
  # add trait information
  get_traits() %>%
  # Only select the plant height
  select_traits_by_domain(
    sel_domain = "Plant heigh"
  )

# Execute the plan
data_la_traits <-
  extract_data(plan_la_traits)
```

Now lets plot the overview of the data

<img src="figures/Example%203%20-%20plot-1.png" style="width:100.0%"
data-fig-align="center" />
