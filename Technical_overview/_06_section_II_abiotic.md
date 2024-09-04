

## Abiotic data

The abiotic data in the **VegVault** database provide essential
information on environmental factors affecting vegetation distribution
and traits. These data include variables such as climate and soil
conditions, which are crucial for understanding the ecological contexts
of vegetation dynamics.

Currently, **VegVault** includes abiotic data from
[CHELSA](https://chelsa-climate.org/),
[CHELSA-TRACE21](https://chelsa-climate.org/chelsa-trace21k/), and
[WoSIS](https://www.isric.org/explore/wosis). CHELSA and CHELSA-TRACE21
provide high-resolution climate data, while WoSIS offers detailed soil
information.

| Variable name | Variable unit    | source of data  |
|---------------|------------------|-----------------|
| bio1          | Â°C              | CHELSA          |
| bio4          | Â°C              | CHELSA          |
| bio6          | Â°C              | CHELSA          |
| bio12         | kg m-2 year-1    | CHELSA          |
| bio15         | Unitless         | CHELSA          |
| bio18         | kg m-2 quarter-1 | CHELSA          |
| bio19         | kg m-2 quarter-1 | CHELSA          |
| HWSD2         | Unitless         | WoSIS-SoilGrids |

<img src="DB_scheme_visualisation/AbioticData.png" style="width:100.0%"
data-fig-align="center" />

Because original data are stored as raster, which cannot be stored in
SQLite database, we created artificial points called `gridpoints` in the
middle of each raster cell to represent the data. To unify the varying
resolution of rasters and to limit the amount of data, we resampled all
data into ~ 25km resolution and 500-year slices. This mean that there we
created uniform spatio-temporal matrix of `gridpoints` to hold the
abiotic data. Gridpoints are stored in artificially created `Datasets`
and `Samples`, with one `Dataset` holding more `Samples` only if the
differ in age. Next, we have estimated the spatial and temporal distance
between each `gridpoint` and other non-`gridpoint` `Samples`
(`vegetation_plot`, `fossil_pollen_archive`, and `traits`). We store the
link between `gridpoint` and non-`gridpoint` `Samples` as well as the
spatial and temporal distance. As this result in very amount of data, we
have discarded any `gridpoint` Sample, which is not close to 50 km
and/or 5000 years to any other non-`gridpoint` `Samples` as not relevant
for the vegetation dynamics.

<img src="../Figures/%20fig_data_grid_coord%20.png" style="width:100.0%"
data-fig-align="center" />

Such data structure allow that environmental context is readily
available for each vegetation and trait `Sample`. while for each
non-`gridpoint` `Sample`, user can select the closest spatio-temporally
abiotic data or get average from all surrounding `gridpoints`.

<img src="DB_scheme_visualisation/AbioticDataReference.png"
style="width:100.0%" data-fig-align="center" />

<img src="../Figures/%20fig_gridpoint_links_example%20.png"
style="width:100.0%" data-fig-align="center" />

By providing comprehensive and well-structured abiotic data, VegVault
enhances the ability to study the interactions between vegetation and
their environment, supporting advanced ecological research and modelling
efforts.
