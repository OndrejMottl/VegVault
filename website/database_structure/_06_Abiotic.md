

## Abiotic Variables {#abiotic-variables .topic-abiotic .topic-icon}

The <span class="abiotic">abiotic data</span> in the
<span class="vegvault">VegVault</span> database provide essential
information on <span class="abiotic">environmental factors</span>
affecting vegetation distribution and
<span class="traits">traits</span>. Currently,
<span class="vegvault">VegVault</span> includes
<span class="abiotic">abiotic data</span> from
[CHELSA](https://chelsa-climate.org/),
[CHELSA-TRACE21](https://doi.org/10.16904/envidat.211), and the
[Harmonized World Soil Database (HWSD)
v2.2](https://data.apps.fao.org/catalog/iso/ff5c613c-75bb-46a9-a162-bc728059b465).
<span class="abiotic">CHELSA</span> and
<span class="abiotic">CHELSA-TRACE21</span> provide high-resolution
<span class="abiotic">climate data</span>, while
<span class="abiotic">HWSD</span> offers detailed
<span class="abiotic">soil information</span>. VegVault 1.0.0 named the
soil source WoSIS; it was HWSD v2.0 or v2.01 (the exact version was not
recorded).

### Abiotic variables (`AbioticVariable`) {#abiotic-variables-abioticvariable .topic-abiotic}

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

Column names and types for table `AbioticVariable`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/AbioticVariable.svg){fig-align="center"
width="100%"}

| Variable name | Variable unit | Source of data |
|----|----|----|
| bio1 | C (degree Celsius) | mean annual air temperature |
| bio4 | C/100 (hundredths of a degree Celsius) | temperature seasonality: standard deviation of the monthly mean temperatures times 100 |
| bio6 | C (degree Celsius) | mean daily minimum air temperature of the coldest month |
| bio12 | kg m-2 year-1 | annual precipitation amount |
| bio15 | Unitless | precipitation seasonality |
| bio18 | kg m-2 quarter-1 | precipitation amount of the warmest quarter |
| bio19 | kg m-2 quarter-1 | precipitation amount of the coldest quarter |
| HWSD2 | Unitless | HWSD-soil_group |

Table showing abiotic variables.

Some properties of the values need attention:

- `bio4` (temperature seasonality) is in hundredths of a degree Celsius,
  as its unit says; in VegVault 1.0.0, the present-day `bio4` was 0
  south of about 65.7° N because of a truncated download.
- A present-day `bio12` (annual precipitation) of 6553.5 kg
  m<sup>-2</sup> is the storage limit of CHELSA V2.1, so it is a lower
  bound.
- CHELSA-TRACE21 stores precipitation in whole kg m<sup>-2</sup>, so a
  dry quarter with less than 0.5 kg m<sup>-2</sup> is 0 in the past
  (`bio18`, `bio19`), while the present-day values come in steps of 0.1.
- In the Sahel and the Sudanian belt, the coldest quarter of `bio19` can
  be the dry winter in one product and the rainy season in the other, so
  `bio19` can change between 0 and several hundred kg m<sup>-2</sup>
  between the present day and the past.

### Abiotic Data (`AbioticData`) {#abiotic-data-abioticdata .topic-abiotic}

The `AbioticData` table holds the actual values of abiotic variables
(the units are the same for each `AbioticVariable`).

| column_name         | data_type | description                  |
|---------------------|-----------|------------------------------|
| sample_id           | INTEGER   | ID of a Sample               |
| abiotic_variable_id | INTEGER   | ID of an Abiotic Variable    |
| abiotic_value       | REAL      | Value of an Abiotic Variable |

Column names and types for table `AbioticData`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/AbioticData.svg){fig-align="center"
width="100%"}

### Gridpoints (`AbioticDataReference`) {#gridpoints-abioticdatareference .topic-abiotic}

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
temporal distance. A link is kept when the two are at most 50 km and at
most 5,000 years apart, and any <span class="abiotic">gridpoint</span>
<span class="database">Sample</span> without a link is discarded as not
relevant for the vegetation dynamics.

Since VegVault 2.0.0, the links are stored once per position, a distinct
combination of longitude, latitude and age, because many
<span class="database">Samples</span> share a position.
`AbioticDataReference` is a view, a stored query: it combines the tables
`SamplePosition` (the position of each
non-<span class="abiotic">gridpoint</span>
<span class="database">Sample</span>) and `PositionLink` (the
<span class="abiotic">gridpoints</span> linked to each position) and
returns one row per <span class="database">Sample</span> and linked
<span class="abiotic">gridpoint</span>, with the same columns as the
table `AbioticDataReference` of VegVault 1.0.0. The positions themselves
are in the table `Positions`.

| column_name       | data_type | description                                    |
|-------------------|-----------|------------------------------------------------|
| sample_id         | INTEGER   | ID of non-gridpoint Sample                     |
| sample_ref_id     | INTEGER   | ID of gridpoint Sample                         |
| distance_in_km    | INTEGER   | Distance among samples expressed in kilometres |
| distance_in_years | INTEGER   | Distance among samples expressed in years      |

Column names and types for view `AbioticDataReference`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/AbioticDataReference.svg){fig-align="center"
width="100%"}

| column_name | data_type | description                     |
|-------------|-----------|---------------------------------|
| position_id | INTEGER   | ID of a position (unique)       |
| coord_long  | REAL      | Longitude of the position       |
| coord_lat   | REAL      | Latitude of the position        |
| age         | REAL      | Age of the position (cal yr BP) |

Column names and types for table `Positions`.

| column_name | data_type | description                      |
|-------------|-----------|----------------------------------|
| sample_id   | INTEGER   | ID of a non-gridpoint Sample     |
| position_id | INTEGER   | ID of the position of the Sample |

Column names and types for table `SamplePosition`.

| column_name | data_type | description |
|----|----|----|
| position_id | INTEGER | ID of a position |
| sample_ref_id | INTEGER | ID of a gridpoint Sample linked to the position |
| distance_in_km | INTEGER | Distance between the position and the gridpoint in whole kilometres |
| distance_in_years | INTEGER | Age difference between the position and the gridpoint in whole years |

Column names and types for table `PositionLink`.

Such data structure allows that environmental context is readily
available for each vegetation and trait
<span class="database">Sample</span>. For each
non-<span class="abiotic">gridpoint</span>
<span class="database">Sample</span>, users can select the closest
spatio-temporally abiotic data or get average from all surrounding
<span class="abiotic">gridpoints</span>.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_data_grid_coord.png){fig-align="center"
width="100%"}

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_gridpoint_links_example.png){fig-align="center"
width="100%"}

### Abiotic Variable Reference (`AbioticVariableReference`) {#abiotic-variable-reference-abioticvariablereference .topic-abiotic}

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
