

## Taxa

The **VegVault** database contains taxa names directly from main *Data
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
**VegVault** database, the
{[taxospace](https://github.com/OndrejMottl/taxospace)} R package has
been utilized, automatically aligning the names to [Taxonomy
Backbone](https://www.gbif.org/dataset/d7dddbf4-2cf0-4f39-9b2a-bb099caae36c)
from [Global Biodiversity Information Facility](https://www.gbif.org/).

Classification up to the family level is then saved for each taxon.

<img src="DB_scheme_visualisation/TaxonClassification.png"
style="width:100.0%" data-fig-align="center" />

<img src="figures/taxa%20classification%20plot-1.png"
style="width:100.0%" data-fig-align="center" />
