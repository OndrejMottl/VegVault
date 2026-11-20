-- Schema prototype: natural keys and range checks
--
-- Applied after without_rowid.sql and tuple_links.sql by
--   13_build_schema_prototypes.R. Adds:
--   - UNIQUE and NOT NULL on Datasets.dataset_name and Samples.sample_name;
--   - CHECK constraints on the documented ranges: coordinates within
--     -180 to 180 and -90 to 90 degrees, link distances within the link
--     rule (0 to 50 km and 0 to 5000 years), and References.mandatory as
--     0 or 1.
-- The constraints are checked while the rows are loaded, so their cost is
--   part of the load time. Ranges that no document fixes (for example of
--   ages or trait values) are left to question 7.
-- Rules of these files: see without_rowid.sql.

CREATE TABLE "Datasets"
(
  "dataset_id" INTEGER PRIMARY KEY,
  "dataset_name" TEXT NOT NULL UNIQUE,
  "data_source_id" INTEGER,
  "dataset_type_id" INTEGER,
  "data_source_type_id" INTEGER,
  "coord_long" REAL CHECK ("coord_long" BETWEEN -180 AND 180),
  "coord_lat" REAL CHECK ("coord_lat" BETWEEN -90 AND 90),
  "sampling_method_id" INTEGER,
  FOREIGN KEY ("dataset_type_id") REFERENCES "DatasetTypeID" ("dataset_type_id"),
  FOREIGN KEY ("sampling_method_id") REFERENCES "SamplingMethodID" ("sampling_method_id"),
  FOREIGN KEY ("data_source_id") REFERENCES "DatasetSourcesID" ("data_source_id"),
  FOREIGN KEY ("data_source_type_id") REFERENCES "DatasetSourceTypeID" ("data_source_type_id")
);

CREATE TABLE "Samples"
(
  "sample_id" INTEGER PRIMARY KEY,
  "sample_name" TEXT NOT NULL UNIQUE,
  "sample_details" TEXT,
  "age" REAL,
  "sample_size_id" INTEGER,
  FOREIGN KEY ("sample_size_id") REFERENCES "SampleSizeID" ("sample_size_id")
);

CREATE TABLE "References"
(
  "reference_id" INTEGER PRIMARY KEY,
  "reference_detail" TEXT,
  "mandatory" BOOLEAN NOT NULL DEFAULT FALSE CHECK ("mandatory" IN (0, 1))
);

CREATE TABLE "Positions"
(
  "position_id" INTEGER PRIMARY KEY,
  "coord_long" REAL NOT NULL CHECK ("coord_long" BETWEEN -180 AND 180),
  "coord_lat" REAL NOT NULL CHECK ("coord_lat" BETWEEN -90 AND 90),
  "age" REAL NOT NULL,
  UNIQUE ("coord_long", "coord_lat", "age")
);

CREATE TABLE "PositionLink"
(
  "position_id" INTEGER NOT NULL,
  "sample_ref_id" INTEGER NOT NULL,
  "distance_in_km" INTEGER NOT NULL
    CHECK ("distance_in_km" BETWEEN 0 AND 50),
  "distance_in_years" INTEGER NOT NULL
    CHECK ("distance_in_years" BETWEEN 0 AND 5000),
  PRIMARY KEY ("position_id", "sample_ref_id"),
  FOREIGN KEY ("position_id") REFERENCES "Positions" ("position_id"),
  FOREIGN KEY ("sample_ref_id") REFERENCES "Samples" ("sample_id")
) WITHOUT ROWID;
