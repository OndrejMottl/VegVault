

# VegVault Database Structure

Currently, VegVault consists of 31 interconnected tables with 87 fields
(variables), which are described in detail below. However, the internal
database structure may not be directly relevant to most users, as the
[{vaultkeepr}](https://bit.ly/vaultkeepr) R package processes all data
to output only the most relevant information in a “ready-to-analyze”
format.

> [!NOTE]
>
> **For Most Users**: If you’re primarily interested in using VegVault
> for research, you may want to start with our [Usage
> Examples](/website/database_examples.qmd) rather than diving into the
> technical database structure.

This section provides comprehensive documentation of all tables and
their relationships for users who need detailed technical information
about the database architecture.

## Metadata Tables

Several tables contain metadata and administrative information that are
not directly linked to the scientific data:

- **`Authors`**: Information about VegVault authors and maintainers,
  including contact details
- **`version_control`**: Database version information with descriptions
  of changes over time  
- **`sqlite_stat1` & `sqlite_stat4`**: SQLite system tables containing
  database index statistics for query optimization

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
