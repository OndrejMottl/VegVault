

# VegVault Database Structure

Currently, <span class="vegvault">VegVault</span> 2.0.0 consists of 34
interconnected tables with 123 fields (variables), and 1 view (a stored
query that combines tables), which are described in detail below.
However, the internal <span class="database">database structure</span>
may not be directly relevant to most users, as the
[{vaultkeepr}](https://bit.ly/vaultkeepr) R package processes all data
to output only the most relevant information in a
“<span class="reproducibility">ready-to-analyze</span>” format.

> [!NOTE]
>
> **For Most Users**: If you’re primarily interested in using
> <span class="vegvault">VegVault</span> for research, you may want to
> start with our [Usage Examples](database_examples.qmd) rather than
> diving into the technical <span class="database">database
> structure</span>.

This section provides comprehensive documentation of all tables and
their relationships for users who need detailed technical information
about the <span class="database">database architecture</span>.

<br>

## Full Database Schema

The diagram shows every table with its columns and the links between
tables; it is drawn from the schema with
`R/Website/render_schema_diagrams.R`, as are the diagrams of the single
tables below. The colour of a table’s header marks its section: brown
for datasets, samples and taxa, teal for traits, olive for abiotic data
and the links to gridpoints, light brown for the references, and black
for the authors and the record of each build.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/schema_diagram.svg){fig-align="center"
width="100%"}

## Metadata Tables

Several tables contain <span class="database">metadata</span> and
administrative information that are not directly linked to the
scientific data:

- `Authors`: Information about <span class="vegvault">VegVault</span>
  authors and maintainers, including contact details
- `version_control`: <span class="database">Database version
  information</span> with descriptions of changes over time and, from
  v2.0.0, how each version was built
- `BuildProducers`: the input files of each build, one row per data file
  type, with the tag of the data release it was read from
- `sqlite_stat1` & `sqlite_stat4`: <span class="database">SQLite system
  tables</span> containing <span class="database">database index
  statistics</span> for query optimization

| column_name     | data_type | description                |
|-----------------|-----------|----------------------------|
| author_id       | INTEGER   | ID of an Author (unique)   |
| author_fullname | TEXT      | Full name of an Author     |
| author_email    | TEXT      | Contact email of an Author |
| author_orcid    | TEXT      | ORCID ID of an Author      |

Column names and types for table `Authors`.

| column_name | data_type | description |
|----|----|----|
| id | INTEGER | ID of a database version (unique) |
| version | TEXT | Version number (unique) |
| update_date | TEXT | Date of the creation of that version |
| changelog | TEXT | Text description of main changes in the database |
| build_profile | TEXT | Configuration profile of the build (`release` for a published version) |
| git_commit | TEXT | Commit of the VegVault code that built the database |
| manifest_sha256 | TEXT | SHA-256 checksum of the file that pins the input files of the build |

Column names and types for table `version_control`.

The versions recorded in this database:

| version | update_date | changelog |
|----|----|----|
| 0.0.2 | 2024-10-17 | Beging the versioning of the database |
| 0.0.3 | 2024-11-18 | Reworked the `References` and flagged `mandatory` |
| 0.0.4 | 2024-12-19 | Update the version control and correct the Dataset References |
| 1.0.0 | 2025-01-20 | First release of the database |
| 2.0.0 | 2026-11-25 | Second release: rebuilt from tagged, checksum-verified releases of the vegetation, fossil pollen, trait and abiotic data, with audited trait units and a corrected linkage of gridpoints to samples |

Versions of VegVault recorded in table `version_control`.

| column_name | data_type | description |
|----|----|----|
| version_id | INTEGER | ID of the database version that the build made (`id` of `version_control`) |
| producer | TEXT | Name of the type of input data file, for example `splot_plots` |
| tag | TEXT | Tag of the data release the file was read from (empty in a development build) |

Column names and types for table `BuildProducers`.

![](D:/GITHUB/VegVault/VegVault/Outputs/Figures/website/DB_scheme_visualisation/BuildProducers.svg){fig-align="center"
width="100%"}

<br>
