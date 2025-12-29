

## Traits

### <span class="traits">Traits Structure Overview</span> (`Traits`)

The <span class="traits">Traits</span> table contains the list of
<span class="traits">functional traits</span> currently contained in
<span class="vegvault">VegVault</span>. The table contains one
<span class="traits">Trait</span> per row, with each
<span class="traits">Trait</span> containing: a unique
<span class="traits">Trait ID</span> (`trait_id`), original
<span class="traits">Trait name</span> from primary source
(`trait_name`), and <span class="traits">Trait Domain</span>
(`trait_domain_id`). <span class="traits">Functional traits</span> of
vegetation <span class="database">taxa</span> follow the same structure
of <span class="database">Dataset</span> and
<span class="database">Samples</span> obtained directly from
<span class="database">Dataset</span>
<span class="database">Source-Types</span>.

| column_name | data_type | description |
|----|----|----|
| trait_id | INTEGER | ID of a Trait (unique) |
| trait_domain_id | INTEGER | ID of a Trait Domain |
| trait_name | TEXT | Name of the trait from the primary source. See ‘VegVault Content’ for the details about the specific columns used from primary sources. |

Column names and types for table `Traits`.

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Traits.png"
style="width:100.0%" data-fig-align="center" />

### <span class="traits">Traits Domain</span> (`TraitsDomain`)

Traits are grouped into <span class="traits">Trait Domains</span> to
allow for easier aggregation of <span class="traits">Traits</span>
across data sources. As there are differences in trait names across
sources of data and individual <span class="database">Datasets</span>,
the <span class="vegvault">VegVault</span> database contains
<span class="traits">Trait Domain</span> information to group traits
together. In total, six <span class="traits">Trait Domains</span> are
present: `Stem specific density`, `Leaf nitrogen content per unit mass`,
`Diaspore mass`, `Plant height`, `Leaf area`, `Leaf mass per area`,
following [Diaz et
al. (2016)](https://www.nature.com/articles/nature16489). Yet, it is up
to the user to decide how to further aggregate trait values if multiple
trait <span class="database">Samples</span> of one
<span class="traits">Trait Domain</span> are available for the same
environmental or taxonomic entity.

| column_name | data_type | description |
|----|----|----|
| trait_domain_id | INTEGER | ID of a Trait Domain (unique) |
| trait_domain_name | TEXT | Name of the Trait Domain from Diaz et al. (2016) |
| trait_domanin_description | TEXT | NA |
| trait_domain_description | NA | Additional information about the Trait Domain |

Column names and types for table `TraitsDomain`.

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitsDomain.png"
style="width:100.0%" data-fig-align="center" />

| Trait domain | Trait | Data Source |
|----|----|----|
| Stem specific density | stem wood density | BIEN |
| Stem specific density | Stem specific density (SSD, stem dry mass per stem fresh volume) or wood density | TRY |
| Leaf nitrogen content per unit mass | leaf nitrogen content per leaf dry mass | BIEN |
| Leaf nitrogen content per unit mass | Leaf nitrogen (N) content per leaf dry mass | TRY |
| Diaspore mass | seed mass | BIEN |
| Diaspore mass | Seed dry mass | TRY |
| Plant heigh | whole plant height | BIEN |
| Plant heigh | Plant height vegetative | TRY |
| Leaf Area | leaf area | BIEN |
| Leaf Area | Leaf area (in case of compound leaves undefined if leaf or leaflet, undefined if petiole is in- or exluded) | TRY |
| Leaf Area | Leaf area (in case of compound leaves: leaf, petiole excluded) | TRY |
| Leaf Area | Leaf area (in case of compound leaves: leaf, petiole included) | TRY |
| Leaf Area | Leaf area (in case of compound leaves: leaf, undefined if petiole in- or excluded) | TRY |
| Leaf mass per area | leaf mass per area | BIEN |
| Leaf mass per area | Leaf area per leaf dry mass (specific leaf area, SLA or 1/LMA): petiole included | TRY |
| Leaf mass per area | Leaf area per leaf dry mass (specific leaf area, SLA or 1/LMA): undefined if petiole is in- or excluded) | TRY |

Overview of Trait Domains and their associated Traits

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_traits_per_domain.png"
style="width:100.0%" data-fig-align="center" />

### <span class="traits">Traits value</span> (`TraitsValue`)

In general, data of functional traits of vegetation taxa follow the same
structure of the <span class="database">Dataset</span> and
<span class="database">Samples</span> obtained directly from the
<span class="database">Dataset Source-Types</span>. Therefore,
`TraitsValue` table contains not only the actual measured value of
<span class="traits">Trait</span> observation but also information about
linking information across <span class="database">Datasets</span>,
<span class="database">Samples</span>, and
<span class="database">Taxa</span>. This comprehensive linkage ensures
that each Trait value is accurately associated with its relevant
ecological, environmental and taxonomic context.

| column_name | data_type | description                                      |
|-------------|-----------|--------------------------------------------------|
| trait_id    | INTEGER   | ID of a Trait                                    |
| dataset_id  | INTEGER   | ID of a Dataset                                  |
| sample_id   | INTEGER   | ID of a Sample                                   |
| taxon_id    | INTEGER   | ID of a Taxon                                    |
| trait_value | REAL      | Value of specific measured observation of Trait. |

Column names and types for table `TraitsValue`.

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitsValue.png"
style="width:100.0%" data-fig-align="center" />

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_occurences_per_dommain.png"
style="width:100.0%" data-fig-align="center" />

### <span class="traits">Traits Reference</span> (`TraitsReference`)

To ensure clarity and reproducibility, each
<span class="traits">Trait</span> in
<span class="vegvault">VegVault</span> can have additional
<span class="database">References</span> beyond the general
<span class="database">Dataset</span> and
<span class="database">Sample</span>
<span class="database">References</span>. These
<span class="traits">Trait</span>-specific
<span class="database">References</span> provide detailed provenance and
citation information, supporting rigorous scientific research and
enabling users to trace the origins and validation of each trait value.

| column_name  | data_type | description       |
|--------------|-----------|-------------------|
| trait_id     | INTEGER   | ID of a Trait     |
| reference_id | INTEGER   | ID of a Reference |

Column names and types for table `TraitsReference`.

<img
src="D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitsReference.png"
style="width:100.0%" data-fig-align="center" />

<br>
