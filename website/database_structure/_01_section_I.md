# Section I: Description of VegVault


**VegVault** is a SQLite interdisciplinary database linking plot-based
vegetation data with functional traits and climate.

Vault integrates data from multiple well-established sources to provide
a comprehensive view of vegetation dynamics. By organizing data into
clearly defined types and providing comprehensive referencing, VegVault
supports detailed and high-quality ecological research. This structured
approach ensures that data are accessible, reliable, traceable, and
facilitate a wide range of analyses and applications across disciplines.

VegVault is organized into several sections to systematically manage the
varying datasets it integrates. The main structure is the `Dataset`,
which serves as the cornerstone of the database structure. `Datasets`
are composed of `Samples`, representing individual data points within
each dataset. Each `Dataset` will only contain several `Samples` if
these differ in age. There are four types of `Datasets`:

1.  contemporary vegetation plots
2.  past vegetation (fossil pollen records)
3.  functional traits
4.  gridpoint (a dataset type created to hold abiotic data, see details
    in Section III).

For the contemporary (1) and past (2) vegetation `Datasets`, the
`Samples` hold information about `Taxa` as derived directly from the
primary data sources. Trait information is organised in separate
`Datasets` (as they are associated with unique information about their
spatio-temporal location, references, etc) but linked to the same `Taxa`
codes as those taxa in the vegetation `Datasets` (if present). Moreover,
each `Taxa`, disregarding of the source, is associated with
classification information (i.e. species, genus and family name; see
Section III).
