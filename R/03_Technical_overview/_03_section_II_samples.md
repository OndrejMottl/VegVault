

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

The **VegVault** database deals with both current and paleo data.
Therefore, each `Sample` has the indication of *age*, with modern
samples being set to 0. To embrace the uncertainty from age-depth
modeling paleo-record, the **VegVault** database has a structure to hold
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
