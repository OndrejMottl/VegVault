# Write a small schema file for the tests of the database writers and
#   return its path. It has the forms the VegVault schema uses: a rowid
#   table with a reserved name (`References`), a `UNIQUE` column, a
#   default and a `CHECK`; a `WITHOUT ROWID` table with a composite key and
#   a foreign key (`Usage`); a table without a key (`Loose`); a view; and
#   one secondary index.
build_writer_test_schema <- function(dir) {
  path_schema <-
    base::file.path(dir, "writer_schema.sql")

  base::writeLines(
    text = c(
      "-- Tables of the writer tests",
      "CREATE TABLE \"References\"",
      "(",
      "  \"reference_id\" INTEGER PRIMARY KEY,",
      "  \"reference_detail\" TEXT NOT NULL UNIQUE,",
      "  \"mandatory\" INTEGER NOT NULL DEFAULT 0",
      "    CHECK (\"mandatory\" IN (0, 1))",
      ");",
      "",
      "CREATE TABLE \"Usage\"",
      "(",
      "  \"reference_id\" INTEGER NOT NULL,",
      "  \"user_name\" TEXT NOT NULL,",
      "  \"value\" REAL CHECK (\"value\" BETWEEN 0 AND 100),",
      "  PRIMARY KEY (\"reference_id\", \"user_name\"),",
      "  FOREIGN KEY (\"reference_id\")",
      "    REFERENCES \"References\" (\"reference_id\")",
      ") WITHOUT ROWID;",
      "",
      "CREATE TABLE \"Loose\"",
      "(",
      "  \"x\" INTEGER,",
      "  \"y\" TEXT",
      ");",
      "",
      "CREATE VIEW \"UsageView\" AS",
      "SELECT \"user_name\" FROM \"Usage\";",
      "",
      "-- Secondary indexes",
      "CREATE INDEX idx_usage_value ON \"Usage\" (\"value\");"
    ),
    con = path_schema
  )

  return(path_schema)
}
