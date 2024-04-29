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
keystone in the VegVault structure.

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

Currently, the **VegVault** consist of those source-types:

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
