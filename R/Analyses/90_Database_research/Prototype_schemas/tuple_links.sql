-- Schema prototype: links per (longitude, latitude, age) position
--
-- Applied after without_rowid.sql by 13_build_schema_prototypes.R. v1
--   links each sample position to gridpoints and then writes the links
--   once per sample at the position. Here the links are stored once per
--   position:
--   - Positions: one row per distinct (coord_long, coord_lat, age) of the
--     non-gridpoint samples;
--   - SamplePosition: the position of each non-gridpoint sample;
--   - PositionLink: the links of each position to gridpoint samples.
--   The view AbioticDataReference returns the v1 rows (one per sample and
--   gridpoint sample), so vaultkeepr 0.1.0 can read the links unchanged.
-- The two temporary tables derive positions and links from the v1 rows of
--   the subset. A 2.0.0 build computes links per position directly, so
--   their time is reported apart from the build time.
-- Rules of these files: see without_rowid.sql.

-- @omit AbioticDataReference
-- @check positions_cover_samples: SELECT (SELECT count(*) FROM main.SamplePosition) = (SELECT count(*) FROM temp.tmp_sample_position)
-- @check one_position_per_key: SELECT count(*) = 0 FROM (SELECT 1 FROM main.Positions GROUP BY coord_long, coord_lat, age HAVING count(*) > 1)

CREATE TABLE "Positions"
(
  "position_id" INTEGER PRIMARY KEY,
  "coord_long" REAL NOT NULL,
  "coord_lat" REAL NOT NULL,
  "age" REAL NOT NULL,
  UNIQUE ("coord_long", "coord_lat", "age")
);

CREATE TABLE "SamplePosition"
(
  "sample_id" INTEGER PRIMARY KEY,
  "position_id" INTEGER NOT NULL,
  FOREIGN KEY ("sample_id") REFERENCES "Samples" ("sample_id"),
  FOREIGN KEY ("position_id") REFERENCES "Positions" ("position_id")
);

CREATE TABLE "PositionLink"
(
  "position_id" INTEGER NOT NULL,
  "sample_ref_id" INTEGER NOT NULL,
  "distance_in_km" INTEGER NOT NULL,
  "distance_in_years" INTEGER NOT NULL,
  PRIMARY KEY ("position_id", "sample_ref_id"),
  FOREIGN KEY ("position_id") REFERENCES "Positions" ("position_id"),
  FOREIGN KEY ("sample_ref_id") REFERENCES "Samples" ("sample_id")
) WITHOUT ROWID;

CREATE TEMP TABLE tmp_sample_position AS
SELECT s.sample_id, d.coord_long, d.coord_lat, s.age
FROM src.Samples AS s
JOIN src.DatasetSample AS ds ON ds.sample_id = s.sample_id
JOIN src.Datasets AS d ON d.dataset_id = ds.dataset_id
WHERE d.dataset_type_id != (
    SELECT dataset_type_id FROM src.DatasetTypeID
    WHERE dataset_type = 'gridpoints'
  )
  AND d.coord_long IS NOT NULL
  AND d.coord_lat IS NOT NULL
  AND s.age IS NOT NULL;

CREATE TEMP TABLE tmp_position_link AS
SELECT DISTINCT
  t.coord_long, t.coord_lat, t.age,
  l.sample_ref_id, l.distance_in_km, l.distance_in_years
FROM temp.tmp_sample_position AS t
JOIN src.AbioticDataReference AS l ON l.sample_id = t.sample_id;

INSERT INTO "Positions" ("coord_long", "coord_lat", "age")
SELECT DISTINCT coord_long, coord_lat, age
FROM temp.tmp_sample_position
ORDER BY coord_long, coord_lat, age;

INSERT INTO "SamplePosition" ("sample_id", "position_id")
SELECT t.sample_id, p.position_id
FROM temp.tmp_sample_position AS t
JOIN main.Positions AS p
  ON p.coord_long = t.coord_long
  AND p.coord_lat = t.coord_lat
  AND p.age = t.age
ORDER BY t.sample_id;

INSERT INTO "PositionLink"
  ("position_id", "sample_ref_id", "distance_in_km", "distance_in_years")
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
  pl.sample_ref_id AS sample_ref_id,
  pl.distance_in_km AS distance_in_km,
  pl.distance_in_years AS distance_in_years
FROM SamplePosition AS sp
JOIN PositionLink AS pl ON pl.position_id = sp.position_id;
