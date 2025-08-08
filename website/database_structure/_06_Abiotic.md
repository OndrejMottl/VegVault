

## <span class="text-background-greenDark text-color-white text-bold">Abiotic Variables</span>

The
<span class="text-background-greenDark text-color-white text-bold">abiotic
data</span> in the
**<span class="text-background-black text-color-white text-bold">VegVault</span>**
database provide essential information on
<span class="text-background-greenDark text-color-white text-bold">environmental
factors</span> affecting vegetation distribution and
<span class="text-background-blueDark text-color-white text-bold">traits</span>.
Currently,
**<span class="text-background-black text-color-white text-bold">VegVault</span>**
includes
<span class="text-background-greenDark text-color-white text-bold">abiotic
data</span> from [CHELSA](https://chelsa-climate.org/),
[CHELSA-TRACE21](https://chelsa-climate.org/chelsa-trace21k/), and
[WoSIS](https://www.isric.org/explore/wosis).
<span class="text-background-greenDark text-color-white text-bold">CHELSA</span>
and
<span class="text-background-greenDark text-color-white text-bold">CHELSA-TRACE21</span>
provide high-resolution
<span class="text-background-greenDark text-color-white text-bold">climate
data</span>, while
<span class="text-background-greenDark text-color-white text-bold">WoSIS</span>
offers detailed
<span class="text-background-greenDark text-color-white text-bold">soil
information</span>.

### <span class="text-background-greenDark text-color-white text-bold">Abiotic variables</span> (`[AbioticVariable]{.text-background-greenDark .text-color-white .text-bold}`)

As
**<span class="text-background-black text-color-white text-bold">VegVault</span>**
contains
<span class="text-background-greenDark text-color-white text-bold">abiotic
variables</span> from several
<span class="text-background-brownDark text-color-white text-bold">primary
sources</span>, the
<span class="text-background-greenDark text-color-white text-bold">`AbioticVariable`</span>
table contains descriptions of
<span class="text-background-greenDark text-color-white text-bold">abiotic
variables</span> (`abiotic_variable_name`), their units
(`abiotic_variable_unit`), and measurement details (`measure_details`).
These data include variables such as
<span class="text-background-greenDark text-color-white text-bold">climate</span>
and
<span class="text-background-greenDark text-color-white text-bold">soil
conditions</span>, which are crucial for understanding the ecological
contexts of vegetation dynamics.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/AbioticVariable.png"
style="width:100.0%" data-fig-align="center" />

| column_name | data_type | description |
|----|----|----|
| abiotic_variable_id | INTEGER | ID of a Abiotic Variable |
| abiotic_variable_name | TEXT | Name of a Abiotic Variable from primary source |
| abiotic_variable_unit | TEXT | Unit of a Abiotic Variable |
| measure_details | TEXT | Additional details about Abiotic Variable |
| abiotic_variable_scale | NA | Scale of a Abiotic Variable |

Column names and types for table AbioticVariable.

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

### Abiotic Data (`AbioticData`)

The `AbioticData` table holds the actual values of abiotic variables
(the units are the same for each `AbioticVariable`).

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/AbioticData.png"
style="width:100.0%" data-fig-align="center" />

### Gridpoints (`AbioticDataReference`)

Gridpoints are stored in artificially created `Datasets` and `Samples`,
with one `Dataset` holding more `Samples` only if they differ in age. We
have estimated the spatial and temporal distance between each
`gridpoint` and other non-`gridpoint` `Samples` (`vegetation_plot`,
`fossil_pollen_archive`, and `traits`). We store the link between
`gridpoint` and non-`gridpoint` `Samples` as well as the spatial and
temporal distance. As this results in very large amounts of data, we
have discarded any `gridpoint` `Sample`, which is not close to 50 km
and/or 5000 years to any other non-`gridpoint` `Samples` as not relevant
for the vegetation dynamics.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_scheme_visualisation/AbioticDataReference.png"
style="width:100.0%" data-fig-align="center" />

| column_name       | data_type | description                                    |
|-------------------|-----------|------------------------------------------------|
| sample_id         | INTEGER   | ID of non-gridpoint Sample                     |
| sample_ref_id     | INTEGER   | ID of gridpoint Sample                         |
| distance_in_km    | INTEGER   | Distance among samples expressed in kilometres |
| distance_in_years | INTEGER   | Distance among samples expressed in years      |

Column names and types for table AbioticDataReference.

Such data structure allows that environmental context is readily
available for each vegetation and trait `Sample`. For each
non-`gridpoint` `Sample`, users can select the closest spatio-temporally
abiotic data or get average from all surrounding `gridpoints`.

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_data_grid_coord.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/Outputs/Figures/website/DB_structure/fig_gridpoint_links_example.png"
style="width:100.0%" data-fig-align="center" />

### Abiotic Variable Reference (`AbioticVariableReference`)

Each `Abiotic Variable` can have a separate `Reference`, in addition to
a `Dataset` and `Sample`.

| column_name         | data_type | description               |
|---------------------|-----------|---------------------------|
| abiotic_variable_id | INTEGER   | ID of an Abiotic Variable |
| reference_id        | INTEGER   | ID of a Reference         |

Column names and types for table AbioticVariableReference.
