

## Abiotic Variables

The <span class="abiotic">abiotic data</span> in the
<span class="vegvault">VegVault</span> database provide essential
information on <span class="abiotic">environmental factors</span>
affecting vegetation distribution and
<span class="traits">traits</span>. Currently,
<span class="vegvault">VegVault</span> includes
<span class="abiotic">abiotic data</span> from
[CHELSA](https://chelsa-climate.org/),
[CHELSA-TRACE21](https://chelsa-climate.org/chelsa-trace21k/), and
[WoSIS](https://www.isric.org/explore/wosis).
<span class="abiotic">CHELSA</span> and
<span class="abiotic">CHELSA-TRACE21</span> provide high-resolution
<span class="abiotic">climate data</span>, while
<span class="abiotic">WoSIS</span> offers detailed
<span class="abiotic">soil information</span>.

### <span class="abiotic">Abiotic variables</span> (`AbioticVariable`)

As <span class="vegvault">VegVault</span> contains
<span class="abiotic">abiotic variables</span> from several
<span class="database">primary sources</span>, the `AbioticVariable`
table contains descriptions of <span class="abiotic">abiotic
variables</span> (`abiotic_variable_name`), their units
(`abiotic_variable_unit`), and measurement details (`measure_details`).
These data include variables such as
<span class="abiotic">climate</span> and <span class="abiotic">soil
conditions</span>, which are crucial for understanding the ecological
contexts of vegetation dynamics.

| column_name | data_type | description |
|----|----|----|
| abiotic_variable_id | INTEGER | ID of a Abiotic Variable |
| abiotic_variable_name | TEXT | Name of a Abiotic Variable from primary source |
| abiotic_variable_unit | TEXT | Unit of a Abiotic Variable |
| measure_details | TEXT | Additional details about Abiotic Variable |
| abiotic_variable_scale | NA | Scale of a Abiotic Variable |

Column names and types for table `AbioticVariable`.

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/AbioticVariable.png"
style="width:100.0%" data-fig-align="center" />

| Variable name | Variable unit | Source of data |
|----|----|----|
| bio1 | C (degree Celsius) | mean annual air temperature |
| bio4 | C (degree Celsius) | temperature seasonality |
| bio6 | C (degree Celsius) | mean daily minimum air temperature of the coldest month |
| bio12 | kg m-2 year-1 | annual precipitation amount |
| bio15 | Unitless | precipitation seasonality |
| bio18 | kg m-2 quarter-1 | mean monthly precipitation amount of the warmest quarter |
| bio19 | kg m-2 quarter-1 | mean monthly precipitation amount of the coldest quarter |
| HWSD2 | Unitless | SoilGrids-soil_class |

Table showing abiotic variables.

### <span class="abiotic">Abiotic Data</span> (`AbioticData`)

The `AbioticData` table holds the actual values of abiotic variables
(the units are the same for each `AbioticVariable`).

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/AbioticData.png"
style="width:100.0%" data-fig-align="center" />

### Gridpoints (`AbioticDataReference`)

Gridpoints are stored in artificially created
<span class="database">Datasets</span> and
<span class="database">Samples</span>, with one
<span class="database">Dataset</span> holding more
<span class="database">Samples</span> only if they differ in age. We
have estimated the spatial and temporal distance between each
<span class="abiotic">gridpoint</span> and other
non-<span class="abiotic">gridpoint</span>
<span class="database">Samples</span> (`vegetation_plot`,
`fossil_pollen_archive`, and `traits`). We store the link between
<span class="abiotic">gridpoint</span> and
non-<span class="abiotic">gridpoint</span>
<span class="database">Samples</span> as well as the spatial and
temporal distance. As this results in very large amounts of data, we
have discarded any <span class="abiotic">gridpoint</span>
<span class="database">Sample</span>, which is not close to 50 km and/or
5000 years to any other non-<span class="abiotic">gridpoint</span>
<span class="database">Samples</span> as not relevant for the vegetation
dynamics.

| column_name       | data_type | description                                    |
|-------------------|-----------|------------------------------------------------|
| sample_id         | INTEGER   | ID of non-gridpoint Sample                     |
| sample_ref_id     | INTEGER   | ID of gridpoint Sample                         |
| distance_in_km    | INTEGER   | Distance among samples expressed in kilometres |
| distance_in_years | INTEGER   | Distance among samples expressed in years      |

Column names and types for table `AbioticDataReference`.

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/AbioticDataReference.png"
style="width:100.0%" data-fig-align="center" />

Such data structure allows that environmental context is readily
available for each vegetation and trait
<span class="database">Sample</span>. For each
non-<span class="abiotic">gridpoint</span>
<span class="database">Sample</span>, users can select the closest
spatio-temporally abiotic data or get average from all surrounding
<span class="abiotic">gridpoints</span>.

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_data_grid_coord.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_gridpoint_links_example.png"
style="width:100.0%" data-fig-align="center" />

### Abiotic Variable Reference (`AbioticVariableReference`)

Each <span class="abiotic">Abiotic Variable</span> can have a separate
<span class="database">Reference</span>, in addition to a
<span class="database">Dataset</span> and
<span class="database">Sample</span>.

| column_name         | data_type | description               |
|---------------------|-----------|---------------------------|
| abiotic_variable_id | INTEGER   | ID of an Abiotic Variable |
| reference_id        | INTEGER   | ID of a Reference         |

Column names and types for table `AbioticVariableReference`.

<br>
