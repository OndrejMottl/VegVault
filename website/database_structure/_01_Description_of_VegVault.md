

# <span class="text-background-black text-color-white text-bold">VegVault Database Structure</span>

Currently,
<span class="text-background-black text-color-white text-bold">VegVault</span>
consists of 31 interconnected tables with 87 fields (variables), which
are described in detail below. However, the internal
<span class="text-background-brownDark text-color-white text-bold">database
structure</span> may not be directly relevant to most users, as the
[{vaultkeepr}](https://bit.ly/vaultkeepr) R package processes all data
to output only the most relevant information in a
“<span class="text-background-brownLight text-color-black text-bold">ready-to-analyze</span>”
format.

> [!NOTE]
>
> **For Most Users**: If you’re primarily interested in using
> <span class="text-background-black text-color-white text-bold">VegVault</span>
> for research, you may want to start with our [Usage
> Examples](.\website/database_examples.qmd) rather than diving into the
> technical
> <span class="text-background-brownDark text-color-white text-bold">database
> structure</span>.

This section provides comprehensive documentation of all tables and
their relationships for users who need detailed technical information
about the
<span class="text-background-brownDark text-color-white text-bold">database
architecture</span>.

## <span class="text-background-brownDark text-color-white text-bold">Metadata Tables</span>

Several tables contain
<span class="text-background-brownDark text-color-white text-bold">metadata</span>
and administrative information that are not directly linked to the
scientific data:

- **<span class="text-background-brownDark text-color-white text-bold">`Authors`</span>**:
  Information about
  <span class="text-background-black text-color-white text-bold">VegVault</span>
  authors and maintainers, including contact details
- **<span class="text-background-brownDark text-color-white text-bold">`version_control`</span>**:
  <span class="text-background-brownDark text-color-white text-bold">Database
  version</span> information with descriptions of changes over time  
- **<span class="text-background-brownDark text-color-white text-bold">`sqlite_stat1`</span>
  &
  <span class="text-background-brownDark text-color-white text-bold">`sqlite_stat4`</span>**:
  SQLite system tables containing
  <span class="text-background-brownLight text-color-black text-bold">database
  index statistics</span> for query optimization

| column_name     | data_type | description                |
|-----------------|-----------|----------------------------|
| author_id       | INTEGER   | ID of an Author (unique)   |
| author_fullname | TEXT      | Full name of an Author     |
| author_email    | TEXT      | Contact email of an Author |
| author_orcid    | TEXT      | ORCID ID of an Author      |

Column names and types for table Authors.

| column_name | data_type | description                                      |
|-------------|-----------|--------------------------------------------------|
| id          | INTEGER   | ID of a database version (unique)                |
| version     | TEXT      | Version number                                   |
| update_date | TEXT      | Date of the creation of that version             |
| changelog   | TEXT      | Text description of main changes in the database |

Column names and types for table version_control.
