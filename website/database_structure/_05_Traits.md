

## Traits {#traits .topic-traits .topic-icon}

### Traits Structure Overview (`Traits`) {#traits-structure-overview-traits .topic-traits}

The <span class="traits">Traits</span> table contains the list of
<span class="traits">functional traits</span> currently contained in
<span class="vegvault">VegVault</span>. The table contains one
<span class="traits">Trait</span> per row, with each
<span class="traits">Trait</span> containing: a unique
<span class="traits">Trait ID</span> (`trait_id`), original
<span class="traits">Trait name</span> from primary source
(`trait_name`), and <span class="traits">Trait Domain</span>
(`trait_domain_id`). <span class="traits">Functional traits</span> of
vegetation <span class="taxa">taxa</span> follow the same structure of
<span class="database">Dataset</span> and
<span class="database">Samples</span> obtained directly from
<span class="database">Dataset</span>
<span class="database">Source-Types</span>.

| column_name | data_type | description |
|----|----|----|
| trait_id | INTEGER | ID of a Trait (unique) |
| trait_domain_id | INTEGER | ID of a Trait Domain |
| trait_name | TEXT | Name of the trait from the primary source. See ‘VegVault Content’ for the details about the specific columns used from primary sources. |

Column names and types for table `Traits`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/Traits.svg){fig-align="center"
width="100%"}

### Traits Domain (`TraitsDomain`) {#traits-domain-traitsdomain .topic-traits}

Traits are grouped into <span class="traits">Trait Domains</span> to
allow for easier aggregation of <span class="traits">Traits</span>
across data sources. As there are differences in trait names across
sources of data and individual <span class="database">Datasets</span>,
the <span class="vegvault">VegVault</span> database contains
<span class="traits">Trait Domain</span> information to group traits
together. In total, 6 <span class="traits">Trait Domains</span> are
present: `Diaspore mass`, `Leaf Area`, `Leaf mass per area`,
`Leaf nitrogen content per unit mass`, `Plant heigh`, and
`Stem specific density`, following [Diaz et
al. (2016)](https://www.nature.com/articles/nature16489). The names are
stored as in VegVault 1.0.0, including the spelling `Plant heigh` for
plant height. Yet, it is up to the user to decide how to further
aggregate trait values if multiple trait
<span class="database">Samples</span> of one <span class="traits">Trait
Domain</span> are available for the same environmental or taxonomic
entity.

| column_name | data_type | description |
|----|----|----|
| trait_domain_id | INTEGER | ID of a Trait Domain (unique) |
| trait_domain_name | TEXT | Name of the Trait Domain from Diaz et al. (2016) |
| trait_unit | TEXT | Canonical unit used by all values in the Trait Domain |
| trait_domanin_description | TEXT | NA |
| trait_domain_description | NA | Additional information about the Trait Domain |

Column names and types for table `TraitsDomain`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitsDomain.svg){fig-align="center"
width="100%"}

| Trait domain | Trait | Data Source |
|----|----|----|
| Diaspore mass | seed mass | BIEN |
| Diaspore mass | Seed dry mass | TRY |
| Leaf Area | leaf area | BIEN |
| Leaf Area | Leaf area (in case of compound leaves undefined if leaf or leaflet, undefined if petiole is in- or exluded) | TRY |
| Leaf Area | Leaf area (in case of compound leaves: leaf, petiole excluded) | TRY |
| Leaf Area | Leaf area (in case of compound leaves: leaf, petiole included) | TRY |
| Leaf Area | Leaf area (in case of compound leaves: leaf, undefined if petiole in- or excluded) | TRY |
| Leaf mass per area | leaf mass per area | BIEN |
| Leaf mass per area | Leaf area per leaf dry mass (specific leaf area, SLA or 1/LMA): petiole included | TRY |
| Leaf mass per area | Leaf area per leaf dry mass (specific leaf area, SLA or 1/LMA): undefined if petiole is in- or excluded) | TRY |
| Leaf nitrogen content per unit mass | leaf nitrogen content per leaf dry mass | BIEN |
| Leaf nitrogen content per unit mass | Leaf nitrogen (N) content per leaf dry mass | TRY |
| Plant heigh | whole plant height | BIEN |
| Plant heigh | Plant height vegetative | TRY |
| Stem specific density | stem wood density | BIEN |
| Stem specific density | Stem specific density (SSD, stem dry mass per stem fresh volume) or wood density | TRY |

Overview of Trait Domains and their associated Traits

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_traits_per_domain.png){fig-align="center"
width="100%"}

### Traits value (`TraitsValue`) {#traits-value-traitsvalue .topic-traits}

In general, data of functional traits of vegetation taxa follow the same
structure of the <span class="database">Dataset</span> and
<span class="database">Samples</span> obtained directly from the
<span class="database">Dataset Source-Types</span>. Therefore,
`TraitsValue` table contains not only the actual measured value of
<span class="traits">Trait</span> observation but also information about
linking information across <span class="database">Datasets</span>,
<span class="database">Samples</span>, and
<span class="taxa">Taxa</span>. This comprehensive linkage ensures that
each Trait value is accurately associated with its relevant ecological,
environmental and taxonomic context.

Since VegVault 2.0.0, every trait value is stored in the unit of its
<span class="traits">Trait Domain</span> (`trait_unit` of
`TraitsDomain`), shown in the table below. Each value references exactly
one versioned conversion rule of `TraitUnitConversion` and, when it is
derived from another trait, one derivation rule of `TraitDerivation`,
such as the reciprocal that turns specific leaf area (SLA) into leaf
mass per area (LMA). The values and units as the data providers reported
them are not stored in the database; they are part of the trait data
release
([VegVault-Trait_data](https://doi.org/10.5281/zenodo.24505585)),
together with the audit tables of the conversion.

| Trait Domain                        | Unit   |
|-------------------------------------|--------|
| Diaspore mass                       | mg     |
| Leaf Area                           | mm2    |
| Leaf mass per area                  | mg/mm2 |
| Leaf nitrogen content per unit mass | mg/g   |
| Plant heigh                         | m      |
| Stem specific density               | g/cm3  |

Unit of the values of each Trait Domain.

| column_name | data_type | description |
|----|----|----|
| trait_id | INTEGER | ID of a Trait |
| dataset_id | INTEGER | ID of a Dataset |
| sample_id | INTEGER | ID of a Sample |
| taxon_id | INTEGER | ID of a Taxon |
| trait_value | REAL | Value of specific measured observation of Trait. |
| trait_unit_conversion_id | INTEGER | ID of the required unit conversion rule |
| trait_derivation_id | INTEGER | ID of an optional derived-trait rule |

Column names and types for table `TraitsValue`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitsValue.svg){fig-align="center"
width="100%"}

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_structure/fig_n_occurences_per_dommain.png){fig-align="center"
width="100%"}

### Trait Unit Conversion (`TraitUnitConversion`) {#trait-unit-conversion-traitunitconversion .topic-traits}

The `TraitUnitConversion` table holds the rules that bring the value of
each data provider to the unit of its <span class="traits">Trait
Domain</span>, one rule per row. A rule applies to one trait of one
provider, and sometimes only to one dataset of that provider, and it is
kept under a unique name and a version, so that every stored value can
be traced to the rule that converted it.

| column_name | data_type | description |
|----|----|----|
| trait_unit_conversion_id | INTEGER | ID of a conversion rule (unique) |
| conversion_rule_key | TEXT | Name of the rule (unique), for example `try_leaf_area_3112_cm2` |
| rule_version | TEXT | Version of the rule |
| source_provider | TEXT | Data provider the rule applies to (`TRY` or `BIEN`) |
| source_trait_id | TEXT | Trait of the data provider the rule applies to |
| source_dataset_key | TEXT | Dataset of the data provider the rule is limited to (empty for all datasets) |
| normalized_original_unit | TEXT | Unit as the data provider reported it, written in one standard way |
| standardized_unit | TEXT | Unit after the conversion, the unit of the Trait Domain |
| trait_dimension | TEXT | Physical dimension of the trait, for example `length` or `area` |
| operation | TEXT | Kind of conversion: `identity`, `multiply` or `reciprocal` |
| multiplier | REAL | Factor of the conversion |
| evidence | TEXT | Reason or source of the rule |

Column names and types for table `TraitUnitConversion`.

### Trait Derivation (`TraitDerivation`) {#trait-derivation-traitderivation .topic-traits}

The `TraitDerivation` table holds the rules that compute one trait from
another after its unit conversion, such as leaf mass per area from
specific leaf area.

| column_name | data_type | description |
|----|----|----|
| trait_derivation_id | INTEGER | ID of a derivation rule (unique) |
| derivation_rule_key | TEXT | Name of the rule (unique), for example `sla_to_lma` |
| rule_version | TEXT | Version of the rule |
| input_unit | TEXT | Unit of the trait the rule starts from |
| output_unit | TEXT | Unit of the derived trait |
| trait_dimension | TEXT | Physical dimension of the derived trait |
| operation | TEXT | Kind of derivation, for example `reciprocal` |
| multiplier | REAL | Factor of the derivation |
| evidence | TEXT | Reason or source of the rule |

Column names and types for table `TraitDerivation`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitUnitConversion.svg){fig-align="center"
width="100%"}

### Traits Reference (`TraitsReference`) {#traits-reference-traitsreference .topic-traits}

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

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/TraitsReference.svg){fig-align="center"
width="100%"}

<br>
