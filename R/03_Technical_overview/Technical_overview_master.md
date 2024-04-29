# VegVault database
Ondřej Mottl
2024-04-29

- [Section I: Description of VegVaul](#section-i-description-of-vegvaul)
- [Section II: Overview of VegVault
  1.0.0](#section-ii-overview-of-vegvault-100)
  - [Dataset](#dataset)
    - [Dataset Type](#dataset-type)
    - [Dataset Source-Type](#dataset-source-type)
    - [Dataset Source](#dataset-source)
    - [Sampling method](#sampling-method)
    - [References](#references)
  - [Samples](#samples)
    - [Dataset-Sample](#dataset-sample)
    - [Sample-size](#sample-size)
    - [Sample age](#sample-age)
    - [Sample reference](#sample-reference)
  - [Taxa](#taxa)
    - [Classification](#classification)
  - [Traits](#traits)
    - [Trait domain](#trait-domain)
    - [Trait Values](#trait-values)
    - [Trait reference](#trait-reference)
  - [Abiotic data](#abiotic-data)
  - [Abiotic data](#abiotic-data-1)
- [Section III: Assembly details of VegVault
  1.0.0](#section-iii-assembly-details-of-vegvault-100)
- [Section IV: Examples of usage](#section-iv-examples-of-usage)
  - [Example 1](#example-1)
  - [Example 2](#example-2)
  - [Example 3](#example-3)
- [Section V: Outlook and future
  directions](#section-v-outlook-and-future-directions)

# Section I: Description of VegVaul

**VegVault** is a SQLite interdisciplinary database linking plot-based
vegetation data with functional traits and climate. Specifically, it
contains:

- current vegetation plot data
- past vegetation plot data (fossil pollen records)
- functional trait data
- current abiotic data (climate, soil)
- past abiotic data (climate)

The goal of the database is to compilate interdisciplinary data …

# Section II: Overview of VegVault 1.0.0

- [Dataset](#dataset)
  - [Dataset Type](#dataset-type)
  - [Dataset Source-Type](#dataset-source-type)
  - [Dataset Source](#dataset-source)
  - [Sampling method](#sampling-method)
  - [References](#references)

The database is structured in several logical levels, such as `Dataset`,
`Sample`, `Taxa`, `Trait`, etc.

## Dataset

`Dataset` represents the highest levels in the hierarchy. It is the main
keystone in the VegVauls structure.

<img src="DB_scheme_visualisation/Datasets.png" style="width:100.0%"
data-fig-align="center" />

### Dataset Type

`dataset_type_id` defines the basic type of a dataset. This is the
highest level of classification of the data

Currently, there **VegVault** consist of those types:

- **vegetation_plot** - current vegetation plot dataset
- **fossil_pollen_archive** - past vegetation plot dataset
- **traits** - dataset containing functional traits
- **gridpoints** - artificially created dataset to hold abiotic data

<img src="DB_scheme_visualisation/DatasetTypeID.png"
style="width:100.0%" data-fig-align="center" />

<img src="figures/Dataset%20type%20-%20plots-1.png" style="width:100.0%"
data-fig-align="center" />

<img src="figures/Dataset%20type%20-%20plots-2.png" style="width:100.0%"
data-fig-align="center" />

<img src="figures/Dataset%20type%20-%20plots-3.png" style="width:100.0%"
data-fig-align="center" />

### Dataset Source-Type

`dataset_source_type_id` defines the general provider of the dataset.
This should help to classify, which data pipeline was used to import the
dataset into the **VegVault**, This is also the first general point of
reference of data, as all large databases have a citation statement.

Currently, there **VegVault** consist of those source-types:

- **BIEN** - [Botanical Information and Ecology
  Network](https://bien.nceas.ucsb.edu/bien/)
- **sPlotOpen** - [The open-access version of
  sPlot](https://idiv-biodiversity.de/en/splot/splotopen.html)
- **TRY** - [TRY Plant Trait
  Database](https://www.try-db.org/TryWeb/Home.php)
- **FOSSILPOL** - [The workflow that aims to process and standardise
  global palaeoecological pollen
  data](https://hope-uib-bio.github.io/FOSSILPOL-website/)
- **gridpoints** - artificially created dataset to hold abiotic data

<img src="DB_scheme_visualisation/DatasetSourceTypeID.png"
style="width:100.0%" data-fig-align="center" />

<img src="figures/dataset%20source%20type%20-%20plots-1.png"
style="width:100.0%" data-fig-align="center" />

<img src="figures/dataset%20source%20type%20-%20plots-2.png"
style="width:100.0%" data-fig-align="center" />

### Dataset Source

Each individual dataset from a specific *Data Source-Type* can have
information on the source of the data (i.e. sub-database). This should
help to promote better findability of the primary source of data and
referencing.

<img src="DB_scheme_visualisation/DatasetSourcesID.png"
style="width:100.0%" data-fig-align="center" />

Currently, there are 706 sources of datasets.

<img src="figures/Dataset%20ID%20-%20plots-1.png" style="width:100.0%"
data-fig-align="center" />

### Sampling method

Some datasets may differ in the way they have been sampled. This could
be represented by different ways vegetation data have been sampled for
*Dataset Type* of `vegetation_plot`, or depositional environment for
*Dataset Type* of `fossil_pollen_archive`.

<img src="DB_scheme_visualisation/SamplingMethodID.png"
style="width:100.0%" data-fig-align="center" />

<img src="figures/Dataset%20Sampling%20method%20-%20plots-1.png"
style="width:100.0%" data-fig-align="center" />

### References

*Dataset Source-Type*, *Dataset Source*, and *Sampling Method* can have
their own references. Moreover, each dataset can have one or more
references directly to that specific data.

<img src="DB_scheme_visualisation/DatasetReference.png"
style="width:100.0%" data-fig-align="center" />

This means that one dataset can have one/several references from each of
those parts. Let’s take a look at an example, of what that could mean in
practice.

We have selected dataset ID: 91256, which is a fossil pollen archive.
Therefore, it has the reference of the *Dataser Source-Type*:
*https://doi.org/10.1111/geb.13693* and reference for the individual
dataset: *Grimm, E.C., 2008. Neotoma: an ecosystem database for the
Pliocene, Pleistocene, and Holocene. Illinois State Museum Scientific
Papers E Series, 1.*

- [Samples](#samples)
  - [Dataset-Sample](#dataset-sample)
  - [Sample-size](#sample-size)
  - [Sample age](#sample-age)
  - [Sample reference](#sample-reference)

## Samples

`Sample` represents the main unit of data in the **VegVault** database.

<img src="DB_scheme_visualisation/Samples.png" style="width:100.0%"
data-fig-align="center" />

### Dataset-Sample

First `Samples` are linked to `Datasets` via the `Dataset-Sample` table.

<img src="DB_scheme_visualisation/DatasetSample.png"
style="width:100.0%" data-fig-align="center" />

<img src="figures/Number%20of%20samples%20plot-1.png"
style="width:100.0%" data-fig-align="center" />

<img src="figures/Number%20of%20samples%20plot-2.png"
style="width:100.0%" data-fig-align="center" />

### Sample-size

Vegetation plots can have different sizes, which can have a huge impact
on analyses. Therefore, the information about the plot is saved
separately.

<img src="DB_scheme_visualisation/SampleSizeID.png" style="width:100.0%"
data-fig-align="center" />

<img src="figures/plot-size%20plot-1.png" style="width:100.0%"
data-fig-align="center" />

### Sample age

The **Vegvault** database deals with both current and paleo data.
therefore, each `Sample` has the indication of *age*, with modern
samples being set to 0. To embrace the uncertainty from age-depth
modeling paleo-record, the **Vegvault** database has a structure to hold
an uncertainty matrix containing information about all *potential ages*
of each `Sample` from a paleo `Dataset`.

<img src="DB_scheme_visualisation/SampleUncertainty.png"
style="width:100.0%" data-fig-align="center" />

We can show this on the previously selected fossil pollen archive with
dataset ID: 91256.

<img src="figures/Sample%20poential%20age%20-%20plot-1.png"
style="width:100.0%" data-fig-align="center" />

### Sample reference

Individual `Sample` can have specific references on top of the reference
to `Dataset`

<img src="DB_scheme_visualisation/SampleReference.png"
style="width:100.0%" data-fig-align="center" />

- [Taxa](#taxa)
  - [Classification](#classification)

## Taxa

The **Vegvault** database contains taxa names directly from main *Data
Source-types*.

<img src="DB_scheme_visualisation/Taxa.png" style="width:100.0%"
data-fig-align="center" />

Individual taxa names are linked to the `Samples` by the `SampleTaxa`
table.

<img src="DB_scheme_visualisation/SampleTaxa.png" style="width:100.0%"
data-fig-align="center" />

<img src="figures/Number%20of%20taxa%20per%20data%20source%20type-1.png"
style="width:100.0%" data-fig-align="center" />

### Classification

In order to obtain classification of all taxa present in the
**Vegvault** database, the
{[taxospace](https://github.com/OndrejMottl/taxospace)} R package has
been utilized, automatically aligning the names to [Taxonomy
Backbone](https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c)
from [Global Biodiversity Information Facility](https://www.gbif.org/).

Classification up to the family level is then saved for each taxon.

<img src="DB_scheme_visualisation/TaxonClassification.png"
style="width:100.0%" data-fig-align="center" />

<img src="figures/taxa%20classification%20plot-1.png"
style="width:100.0%" data-fig-align="center" />

- [Traits](#traits)
  - [Trait domain](#trait-domain)
  - [Trait Values](#trait-values)
  - [Trait reference](#trait-reference)

## Traits

Functional traits of vegetation taxa follow the same structure of
`Dataset` and `Samples` obtained directly from *Dataset Source-types*.

<img src="DB_scheme_visualisation/Traits.png" style="width:100.0%"
data-fig-align="center" />

### Trait domain

As there are many varying names for the same “traits”, the **Vegvault**
database contains *Trait Domain* information to group traits together.

<img src="DB_scheme_visualisation/TraitsDomain.png" style="width:100.0%"
data-fig-align="center" />

There are currently 6 trait domains following the [Diaz et
al. (2016)](https://www.nature.com/articles/nature16489)

| Trait domain                        |
|-------------------------------------|
| Stem specific density               |
| Leaf nitrogen content per unit mass |
| Diaspore mass                       |
| Plant heigh                         |
| Leaf Area                           |
| Leaf mass per area                  |

<img src="figures/trait%20per%20domain%20plot-1.png"
style="width:100.0%" data-fig-align="center" />

### Trait Values

To store a trait value, information needs to be linked among `Dataset`,
`Sample`, `Taxa`, and `Trait`.

<img src="DB_scheme_visualisation/TraitsValue.png" style="width:100.0%"
data-fig-align="center" />

<img src="figures/trait%20value%20occurences%20plot-1.png"
style="width:100.0%" data-fig-align="center" />

### Trait reference

For full clarity, on top of `Dataset` and `Sample`, each `Trait` can
have additional references.

<img src="DB_scheme_visualisation/TraitsReference.png"
style="width:100.0%" data-fig-align="center" />

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
for the past. this is to reduce the size of the past climate data.

<img src="figures/exampe%20of%20abitic%20data%20-%20soil-1.png"
style="width:100.0%" data-fig-align="center" />

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
for the past. this is to reduce the size of the past climate data.

<img src="figures/exampe%20of%20abitic%20data%20-%20soil-1.png"
style="width:100.0%" data-fig-align="center" />

# Section III: Assembly details of VegVault 1.0.0

# Section IV: Examples of usage

- [Example 1](#example-1)
- [Example 2](#example-2)
- [Example 3](#example-3)

## Example 1

## Example 2

## Example 3

# Section V: Outlook and future directions
