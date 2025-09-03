CREATE TABLE public.annual_co_emissions_by_region (
  entity                TEXT        NOT NULL,
  code                  TEXT,
  year                  INTEGER     NOT NULL,
  annual_co2_emissions  NUMERIC,   -- changed from BIGINT → NUMERIC
  CONSTRAINT annual_co_emissions_by_region_pk PRIMARY KEY (entity, year)
);

CREATE TABLE public.continents_according_to_owid (
  entity     TEXT    NOT NULL,               -- country/territory name - unique in this file
  code       TEXT,                           -- may be NULL for some entities
  year       INTEGER NOT NULL,               -- 2023 in this file
  world_region_owid TEXT  NOT NULL,          
  CONSTRAINT continents_according_to_owid_pk PRIMARY KEY (entity)
);

/* \copy public.continents_according_to_owid (entity, code, year, world_region_owid)
FROM '/Users/medhasubramaniyan/Desktop/data_set/emissions/continents-according-to-our-world-in-data/continents-according-to-our-world-in-data.csv' CSV HEADER; */

/*\copy public.annual_co_emissions_by_region (entity, code, year, annual_co2_emissions) FROM '/Users/medhasubramaniyan/Desktop/data_set/emissions/annual-co-emissions-by-region.csv' CSV HEADER;*/ 
