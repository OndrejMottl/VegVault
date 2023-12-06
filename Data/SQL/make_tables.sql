CREATE TABLE "Datasets"
(
  "dataset_id" varchar PRIMARY KEY
);

CREATE TABLE "DatasetSources"
(
  "dataset_id" varchar,
  "data_source_id" int,
  FOREIGN KEY
("dataset_id") REFERENCES "Datasets"
("dataset_id"),
FOREIGN KEY
("data_source_id") REFERENCES "DatasetSourcesID"
("data_source_id")
);

CREATE TABLE "DatasetSourcesID"
(
  "data_source_id" int PRIMARY KEY,
  "data_source_desc" varchar
);

CREATE TABLE "DatasetType"
(
  "dataset_id" varchar,
  "dataset_type_id" int,
  FOREIGN KEY
("dataset_id") REFERENCES "Datasets"
("dataset_id"),
FOREIGN KEY
("dataset_type_id") REFERENCES "DatasetTypeID"
("dataset_type_id")
);

CREATE TABLE "DatasetTypeID"
(
  "dataset_type_id" int PRIMARY KEY,
  "dataset_type" varchar
);

CREATE TABLE "DatasetCoord"
(
  "dataset_id" varchar,
  "coord_long" numeric,
  "coord_lat" numeric,
  FOREIGN KEY
("dataset_id") REFERENCES "Datasets"
("dataset_id")
);

CREATE TABLE "SamplingMethodID"
(
  "sampling_method_id" int PRIMARY KEY,
  "sampling_method_details" varchar
);

CREATE TABLE "DatasetSamplingMethod"
(
  "dataset_id" varchar,
  "sampling_method_id" int,
  FOREIGN KEY
("dataset_id") REFERENCES "Datasets"
("dataset_id"),
FOREIGN KEY
("sampling_method_id") REFERENCES "SamplingMethodID"
("sampling_method_id")
);

CREATE TABLE "Samples"
(
  "sample_id" varchar PRIMARY KEY
);

CREATE TABLE "DatasetSample"
(
  "dataset_id" varchar,
  "sample_id" varchar,
  FOREIGN KEY
("dataset_id") REFERENCES "Datasets"
("dataset_id"),
FOREIGN KEY
("sample_id") REFERENCES "Samples"
("sample_id")
);

CREATE TABLE "SampleDetail"
(
  "sample_id" varchar,
  "sample_details" varchar,
  "sample_referecne" varchar,
  FOREIGN KEY
("sample_id") REFERENCES "Samples"
("sample_id")
);

CREATE TABLE "SampleAge"
(
  "sample_id" varchar,
  "age" numeric,
  FOREIGN KEY
("sample_id") REFERENCES "Samples"
("sample_id")
);

CREATE TABLE "SampleUncern"
(
  "sample_id" varchar,
  "iteration" int,
  "age" int,
  FOREIGN KEY
("sample_id") REFERENCES "Samples"
("sample_id")
);

CREATE TABLE "SampleTaxa"
(
  "sample_id" varchar,
  "taxon_id" int,
  "value" numeric,
  FOREIGN KEY
("sample_id") REFERENCES "Samples"
("sample_id"),
FOREIGN KEY
("taxon_id") REFERENCES "Taxa"
("taxon_id")
);

CREATE TABLE "SampleSizeID"
(
  "sample_size_id" int PRIMARY KEY,
  "sample_size" numeric
);

CREATE TABLE "SampleSizeDetails"
(
  "sample_size_id" int,
  "description" varchar,
  FOREIGN KEY
("sample_size_id") REFERENCES "SampleSizeID"
("sample_size_id")
);

CREATE TABLE "SampleSize"
(
  "sample_id" varchar,
  "sample_size_id" int,
  FOREIGN KEY
("sample_id") REFERENCES "Samples"
("sample_id"),
FOREIGN KEY
("sample_size_id") REFERENCES "SampleSizeID"
("sample_size_id")
);

CREATE TABLE "Taxa"
(
  "taxon_id" int PRIMARY KEY,
  "taxon_name" varchar
);

CREATE TABLE "TaxonClassification"
(
  "taxon_id" int,
  "taxon_name_raw" int,
  "taxon_name_agree" int,
  "taxon_name_exact" int,
  "taxon_species" int,
  "taxon_genus" int,
  "taxon_family" int,
  FOREIGN KEY
("taxon_id") REFERENCES "Taxa"
("taxon_id"),
FOREIGN KEY
("taxon_name_raw") REFERENCES "Taxa"
("taxon_id"),
FOREIGN KEY
("taxon_name_agree") REFERENCES "Taxa"
("taxon_id"),
FOREIGN KEY
("taxon_species") REFERENCES "Taxa"
("taxon_id"),
FOREIGN KEY
("taxon_genus") REFERENCES "Taxa"
("taxon_id"),
FOREIGN KEY
("taxon_family") REFERENCES "Taxa"
("taxon_id")
);

CREATE TABLE "Traits"
(
  "trait_id" int PRIMARY KEY,
  "trait_name" varchar,
  "references" varchar
);

CREATE TABLE "TraitsValue"
(
  "trait_id" int,
  "dataset_id" varchar,
  "sample_id" varchar,
  "taxon_id" int,
  "trait_value" numeric,
  FOREIGN KEY
("trait_id") REFERENCES "Traits"
("trait_id"),
FOREIGN KEY
("dataset_id") REFERENCES "Datasets"
("dataset_id"),
FOREIGN KEY
("sample_id") REFERENCES "Samples"
("sample_id"),
FOREIGN KEY
("taxon_id") REFERENCES "Taxa"
("taxon_id")
);

CREATE TABLE "AbioticData"
(
  "sample_id" varchar,
  "value" numeric,
  "measure_details" varchar,
  FOREIGN KEY
("sample_id") REFERENCES "Samples"
("sample_id")
);
