-- Schema prototype: gridpoints in their own tables
--
-- Applied after without_rowid.sql and tuple_links.sql by
--   13_build_schema_prototypes.R. v1 stores each gridpoint cell as a row of
--   Datasets and each gridpoint (cell and age) as a row of Samples, with
--   DatasetSample, DatasetReferences and SampleReference rows. Here:
--   - GridpointCells: one row per cell (the v1 dataset id is kept);
--   - Gridpoints: one row per cell and age (the v1 sample id is kept, so
--     the link ids do not change);
--   - GridpointValues: the climate and soil values (v1 AbioticData, which
--     holds values of gridpoints only);
--   - Datasets, Samples, DatasetSample, DatasetReferences and
--     SampleReference keep only the non-gridpoint rows. Every gridpoint row
--     of the two reference tables names the same reference, which the
--     gridpoint data source and source type already carry.
-- No view keeps the v1 shape of the gridpoint rows: the vaultkeepr 0.1.0
--   workloads show which functions such a change breaks. The view
--   AbioticDataReference keeps its v1 columns, with gridpoint ids as
--   sample_ref_id.
-- Rules of these files: see without_rowid.sql.

-- @omit AbioticData
-- @check cells_complete: SELECT (SELECT count(*) FROM main.GridpointCells) = (SELECT count(*) FROM src.Datasets WHERE dataset_type_id = (SELECT dataset_type_id FROM src.DatasetTypeID WHERE dataset_type = 'gridpoints'))
-- @check gridpoints_complete: SELECT (SELECT count(*) FROM main.Gridpoints) = (SELECT count(*) FROM src.DatasetSample AS ds JOIN src.Datasets AS d ON d.dataset_id = ds.dataset_id WHERE d.dataset_type_id = (SELECT dataset_type_id FROM src.DatasetTypeID WHERE dataset_type = 'gridpoints'))
-- @check values_complete: SELECT (SELECT count(*) FROM main.GridpointValues) = (SELECT count(*) FROM src.AbioticData)
-- @check gridpoint_reference_single: SELECT count(DISTINCT reference_id) = 1 FROM src.SampleReference WHERE sample_id IN (SELECT gridpoint_id FROM main.Gridpoints)
-- @check gridpoint_age_integral: SELECT count(*) = 0 FROM src.Samples WHERE sample_id IN (SELECT gridpoint_id FROM main.Gridpoints) AND age != CAST(age AS INTEGER)

CREATE TABLE "GridpointCells"
(
  "cell_id" INTEGER PRIMARY KEY,
  "coord_long" REAL NOT NULL,
  "coord_lat" REAL NOT NULL,
  UNIQUE ("coord_long", "coord_lat")
);

CREATE TABLE "Gridpoints"
(
  "gridpoint_id" INTEGER PRIMARY KEY,
  "cell_id" INTEGER NOT NULL,
  "age" INTEGER NOT NULL,
  UNIQUE ("cell_id", "age"),
  FOREIGN KEY ("cell_id") REFERENCES "GridpointCells" ("cell_id")
);

CREATE TABLE "GridpointValues"
(
  "gridpoint_id" INTEGER NOT NULL,
  "abiotic_variable_id" INTEGER NOT NULL,
  "abiotic_value" REAL,
  PRIMARY KEY ("gridpoint_id", "abiotic_variable_id"),
  FOREIGN KEY ("gridpoint_id") REFERENCES "Gridpoints" ("gridpoint_id"),
  FOREIGN KEY ("abiotic_variable_id") REFERENCES "AbioticVariable" ("abiotic_variable_id")
) WITHOUT ROWID;

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

CREATE TEMP TABLE tmp_gridpoint_dataset AS
SELECT dataset_id
FROM src.Datasets
WHERE dataset_type_id = (
  SELECT dataset_type_id FROM src.DatasetTypeID
  WHERE dataset_type = 'gridpoints'
);

CREATE TEMP TABLE tmp_gridpoint_sample AS
SELECT ds.sample_id, ds.dataset_id
FROM src.DatasetSample AS ds
WHERE ds.dataset_id IN (SELECT dataset_id FROM temp.tmp_gridpoint_dataset);

INSERT INTO "Datasets"
SELECT *
FROM src.Datasets
WHERE dataset_id NOT IN (SELECT dataset_id FROM temp.tmp_gridpoint_dataset)
ORDER BY dataset_id;

INSERT INTO "Samples"
SELECT *
FROM src.Samples
WHERE sample_id NOT IN (SELECT sample_id FROM temp.tmp_gridpoint_sample)
ORDER BY sample_id;

INSERT INTO "DatasetSample" ("dataset_id", "sample_id")
SELECT dataset_id, sample_id
FROM src.DatasetSample
WHERE dataset_id NOT IN (SELECT dataset_id FROM temp.tmp_gridpoint_dataset)
ORDER BY dataset_id, sample_id;

INSERT INTO "DatasetReferences" ("dataset_id", "reference_id")
SELECT dataset_id, reference_id
FROM src.DatasetReferences
WHERE dataset_id NOT IN (SELECT dataset_id FROM temp.tmp_gridpoint_dataset)
ORDER BY dataset_id, reference_id;

INSERT INTO "SampleReference" ("sample_id", "reference_id")
SELECT sample_id, reference_id
FROM src.SampleReference
WHERE sample_id NOT IN (SELECT sample_id FROM temp.tmp_gridpoint_sample)
ORDER BY sample_id, reference_id;

INSERT INTO "GridpointCells" ("cell_id", "coord_long", "coord_lat")
SELECT dataset_id, coord_long, coord_lat
FROM src.Datasets
WHERE dataset_id IN (SELECT dataset_id FROM temp.tmp_gridpoint_dataset)
ORDER BY dataset_id;

INSERT INTO "Gridpoints" ("gridpoint_id", "cell_id", "age")
SELECT t.sample_id, t.dataset_id, CAST(s.age AS INTEGER)
FROM temp.tmp_gridpoint_sample AS t
JOIN src.Samples AS s ON s.sample_id = t.sample_id
ORDER BY t.sample_id;

INSERT INTO "GridpointValues"
  ("gridpoint_id", "abiotic_variable_id", "abiotic_value")
SELECT sample_id, abiotic_variable_id, abiotic_value
FROM src.AbioticData
WHERE sample_id IN (SELECT sample_id FROM temp.tmp_gridpoint_sample)
ORDER BY sample_id, abiotic_variable_id;

INSERT INTO "PositionLink"
  ("position_id", "gridpoint_id", "distance_in_km", "distance_in_years")
SELECT p.position_id, t.sample_ref_id, t.distance_in_km, t.distance_in_years
FROM temp.tmp_position_link AS t
JOIN main.Positions AS p
  ON p.coord_long = t.coord_long
  AND p.coord_lat = t.coord_lat
  AND p.age = t.age
ORDER BY p.position_id, t.sample_ref_id;

CREATE VIEW "AbioticDataReference" AS
SELECT
  sp.sample_id AS sample_id,
  pl.gridpoint_id AS sample_ref_id,
  pl.distance_in_km AS distance_in_km,
  pl.distance_in_years AS distance_in_years
FROM SamplePosition AS sp
JOIN PositionLink AS pl ON pl.position_id = sp.position_id;
