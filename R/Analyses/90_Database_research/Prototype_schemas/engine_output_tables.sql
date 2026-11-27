-- Output schema of the build-engine benchmark (17a_run_build_engine.R)
--
-- Every engine writes the same tables, so their outputs can be compared
--   row by row. The layout follows the question 4 prototypes: composite
--   primary keys on the junction and value tables (WITHOUT ROWID, except
--   SampleTaxa) and links once per (longitude, latitude, age) position.
--   Gridpoints have a simple table of their own here, so that the
--   benchmark does not depend on how #89 and #90 name and number gridpoint
--   datasets and samples. BuildChunks and BuildSteps record finished work,
--   so that the incremental engine can resume.
-- Rules: one statement per `;` at a line end and full-line comments only.

CREATE TABLE "version_control"
(
  "id" INTEGER PRIMARY KEY,
  "version" TEXT,
  "update_date" TEXT DEFAULT CURRENT_DATE,
  "changelog" TEXT
);

CREATE TABLE "Authors"
(
  "author_id" INTEGER PRIMARY KEY,
  "author_fullname" TEXT,
  "author_email" TEXT,
  "author_orcid" TEXT
);

CREATE TABLE "Datasets"
(
  "dataset_id" INTEGER PRIMARY KEY,
  "dataset_name" TEXT,
  "data_source_id" INTEGER,
  "dataset_type_id" INTEGER,
  "data_source_type_id" INTEGER,
  "coord_long" REAL,
  "coord_lat" REAL,
  "sampling_method_id" INTEGER
);

CREATE TABLE "DatasetReferences"
(
  "dataset_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("dataset_id", "reference_id")
) WITHOUT ROWID;

CREATE TABLE "DatasetTypeID"
(
  "dataset_type_id" INTEGER PRIMARY KEY,
  "dataset_type" TEXT
);

CREATE TABLE "DatasetSourceTypeID"
(
  "data_source_type_id" INTEGER PRIMARY KEY,
  "dataset_source_type" TEXT
);

CREATE TABLE "DatasetSourceTypeReference"
(
  "data_source_type_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("data_source_type_id", "reference_id")
) WITHOUT ROWID;

CREATE TABLE "DatasetSourcesID"
(
  "data_source_id" INTEGER PRIMARY KEY,
  "data_source_desc" TEXT
);

CREATE TABLE "DatasetSourcesReference"
(
  "data_source_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("data_source_id", "reference_id")
) WITHOUT ROWID;

CREATE TABLE "SamplingMethodID"
(
  "sampling_method_id" INTEGER PRIMARY KEY,
  "sampling_method_details" TEXT
);

CREATE TABLE "SamplingMethodReference"
(
  "sampling_method_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("sampling_method_id", "reference_id")
) WITHOUT ROWID;

CREATE TABLE "Samples"
(
  "sample_id" INTEGER PRIMARY KEY,
  "sample_name" TEXT,
  "sample_details" TEXT,
  "age" REAL,
  "sample_size_id" INTEGER
);

CREATE TABLE "SampleReference"
(
  "sample_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("sample_id", "reference_id")
) WITHOUT ROWID;

CREATE TABLE "DatasetSample"
(
  "dataset_id" INTEGER NOT NULL,
  "sample_id" INTEGER NOT NULL,
  PRIMARY KEY ("dataset_id", "sample_id")
) WITHOUT ROWID;

CREATE TABLE "SampleUncertainty"
(
  "sample_id" INTEGER NOT NULL,
  "iteration" INTEGER NOT NULL,
  "age" INTEGER,
  PRIMARY KEY ("sample_id", "iteration")
) WITHOUT ROWID;

CREATE TABLE "SampleSizeID"
(
  "sample_size_id" INTEGER PRIMARY KEY,
  "sample_size" REAL,
  "description" TEXT
);

CREATE TABLE "SampleTaxa"
(
  "sample_id" INTEGER,
  "taxon_id" INTEGER,
  "value" REAL
);

CREATE TABLE "Taxa"
(
  "taxon_id" INTEGER PRIMARY KEY,
  "taxon_name" TEXT
);

CREATE TABLE "TaxonClassification"
(
  "taxon_id" INTEGER PRIMARY KEY,
  "taxon_species" INTEGER,
  "taxon_genus" INTEGER,
  "taxon_family" INTEGER
);

CREATE TABLE "TaxonReference"
(
  "taxon_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("taxon_id", "reference_id")
) WITHOUT ROWID;

CREATE TABLE "TraitsDomain"
(
  "trait_domain_id" INTEGER PRIMARY KEY,
  "trait_domain_name" TEXT,
  "trait_domanin_description" TEXT
);

CREATE TABLE "Traits"
(
  "trait_id" INTEGER PRIMARY KEY,
  "trait_domain_id" INTEGER,
  "trait_name" TEXT
);

CREATE TABLE "TraitsValue"
(
  "trait_id" INTEGER NOT NULL,
  "dataset_id" INTEGER NOT NULL,
  "sample_id" INTEGER NOT NULL,
  "taxon_id" INTEGER NOT NULL,
  "trait_value" REAL,
  PRIMARY KEY ("dataset_id", "sample_id", "trait_id", "taxon_id")
) WITHOUT ROWID;

CREATE TABLE "TraitsReference"
(
  "trait_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("trait_id", "reference_id")
) WITHOUT ROWID;

CREATE TABLE "AbioticVariable"
(
  "abiotic_variable_id" INTEGER PRIMARY KEY,
  "abiotic_variable_name" TEXT,
  "abiotic_variable_unit" TEXT,
  "measure_details" TEXT
);

CREATE TABLE "AbioticVariableReference"
(
  "abiotic_variable_id" INTEGER NOT NULL,
  "reference_id" INTEGER NOT NULL,
  PRIMARY KEY ("abiotic_variable_id", "reference_id")
) WITHOUT ROWID;

CREATE TABLE "References"
(
  "reference_id" INTEGER PRIMARY KEY,
  "reference_detail" TEXT,
  "mandatory" BOOLEAN NOT NULL DEFAULT FALSE
);

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
  "position_id" INTEGER NOT NULL
);

CREATE TABLE "Gridpoints"
(
  "gridpoint_id" INTEGER PRIMARY KEY,
  "coord_long" REAL NOT NULL,
  "coord_lat" REAL NOT NULL,
  "age" INTEGER NOT NULL
);

CREATE TABLE "PositionLink"
(
  "position_id" INTEGER NOT NULL,
  "gridpoint_id" INTEGER NOT NULL,
  "distance_in_km" INTEGER NOT NULL,
  "distance_in_years" INTEGER NOT NULL,
  PRIMARY KEY ("position_id", "gridpoint_id")
) WITHOUT ROWID;

CREATE TABLE "GridpointValues"
(
  "gridpoint_id" INTEGER NOT NULL,
  "abiotic_variable_id" INTEGER NOT NULL,
  "abiotic_value" REAL,
  PRIMARY KEY ("gridpoint_id", "abiotic_variable_id")
) WITHOUT ROWID;

CREATE TABLE "BuildChunks"
(
  "chunk" INTEGER PRIMARY KEY,
  "n_positions" INTEGER NOT NULL,
  "n_links" INTEGER NOT NULL
);

CREATE TABLE "BuildSteps"
(
  "step" TEXT PRIMARY KEY,
  "n_rows" INTEGER NOT NULL
);
