

- [Abiotic data](#abiotic-data)

## Abiotic data

Abiotic data is aimed to provide information about all relevant abiotic
information affecting vegetation distribution and its traits.

Abiotic data is linked to the structure of the **VegVault** Database by
the `gridpoints`, which are artificially created points to *reasonably*
cover the resolution of both modern and past data for vegetation and
abiotic data.

<img src="figures/distribution%20of%20gridpoints-1.png"
style="width:100.0%" data-fig-align="center" />

There are currently abiotic from [CHELSA](https://chelsa-climate.org/)
and [CHELSA-TRACE21](https://chelsa-climate.org/chelsa-trace21k/) and
[WoSIS](https://www.isric.org/explore/wosis). CHELSA and CHELSA-TRACE21
are built on the same structure of variables (visit the websites for
more info).

| Variable name | Variable unit    | source of data  |
|---------------|------------------|-----------------|
| bio1          | °C               | CHELSA          |
| bio4          | °C               | CHELSA          |
| bio6          | °C               | CHELSA          |
| bio12         | kg m-2 year-1    | CHELSA          |
| bio15         | Unitless         | CHELSA          |
| bio18         | kg m-2 quarter-1 | CHELSA          |
| bio19         | kg m-2 quarter-1 | CHELSA          |
| HWSD2         | Unitless         | WoSIS-SoilGrids |

Abiotic data is simply linked to `Samples`.

<img src="DB_scheme_visualisation/AbioticData.png" style="width:100.0%"
data-fig-align="center" />

<img src="figures/exampe%20of%20abitic%20data%20-%20bio1-1.png"
style="width:100.0%" data-fig-align="center" />

Note that the spatial resolution is higher for modern climate data than
for the past. This is to reduce the size of the past climate data.

<img src="figures/exampe%20of%20abitic%20data%20-%20soil-1.png"
style="width:100.0%" data-fig-align="center" />
