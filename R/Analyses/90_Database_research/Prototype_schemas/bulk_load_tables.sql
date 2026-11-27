-- Tables of the bulk-load benchmark (21a_run_bulk_load.R): the position
--   tables of the question 4 layout, with foreign keys, so that
--   `foreign_keys = ON` has something to check.
-- Rules: one statement per `;` at a line end and full-line comments only.

CREATE TABLE "Positions"
(
  "position_id" INTEGER PRIMARY KEY,
  "coord_long" REAL NOT NULL,
  "coord_lat" REAL NOT NULL,
  "age" REAL NOT NULL,
  UNIQUE ("coord_long", "coord_lat", "age")
);

CREATE TABLE "Gridpoints"
(
  "gridpoint_id" INTEGER PRIMARY KEY,
  "coord_long" REAL NOT NULL,
  "coord_lat" REAL NOT NULL,
  "age" INTEGER NOT NULL
);

CREATE TABLE "SamplePosition"
(
  "sample_id" INTEGER PRIMARY KEY,
  "position_id" INTEGER NOT NULL,
  FOREIGN KEY ("position_id") REFERENCES "Positions" ("position_id")
);

CREATE TABLE "PositionLink"
(
  "position_id" INTEGER NOT NULL,
  "gridpoint_id" INTEGER NOT NULL,
  "distance_in_km" INTEGER NOT NULL,
  "distance_in_years" INTEGER NOT NULL,
  PRIMARY KEY ("position_id", "gridpoint_id"),
  FOREIGN KEY ("position_id") REFERENCES "Positions" ("position_id"),
  FOREIGN KEY ("gridpoint_id") REFERENCES "Gridpoints" ("gridpoint_id")
) WITHOUT ROWID;
