CREATE SCHEMA IF NOT EXISTS hw4;

DROP TABLE IF EXISTS hw4.raw_collisions;

CREATE TABLE hw4.raw_collisions (
    collision_index TEXT,
    collision_year TEXT,
    collision_ref_no TEXT,
    location_easting_osgr TEXT,
    location_northing_osgr TEXT,
    longitude TEXT,
    latitude TEXT,
    police_force TEXT,
    collision_severity TEXT,
    number_of_vehicles TEXT,
    number_of_casualties TEXT,
    collision_date TEXT,
    day_of_week TEXT,
    collision_time TEXT,
    local_authority_district TEXT,
    local_authority_ons_district TEXT,
    local_authority_highway TEXT,
    local_authority_highway_current TEXT,
    first_road_class TEXT,
    first_road_number TEXT,
    road_type TEXT,
    speed_limit TEXT,
    junction_detail_historic TEXT,
    junction_detail TEXT,
    junction_control TEXT,
    second_road_class TEXT,
    second_road_number TEXT,
    pedestrian_crossing_human_control_historic TEXT,
    pedestrian_crossing_physical_facilities_historic TEXT,
    pedestrian_crossing TEXT,
    light_conditions TEXT,
    weather_conditions TEXT,
    road_surface_conditions TEXT,
    special_conditions_at_site TEXT,
    carriageway_hazards_historic TEXT,
    carriageway_hazards TEXT,
    urban_or_rural_area TEXT,
    did_police_officer_attend_scene_of_accident TEXT,
    trunk_road_flag TEXT,
    lsoa_of_accident_location TEXT,
    enhanced_severity_collision TEXT,
    collision_injury_based TEXT,
    collision_adjusted_severity_serious TEXT,
    collision_adjusted_severity_slight TEXT
);

COPY hw4.raw_collisions
FROM '/source/source.csv'
WITH (
    FORMAT csv,
    HEADER true,
    DELIMITER ',',
    NULL ''
);

DROP TABLE IF EXISTS hw4.fact_collisions;

CREATE TABLE hw4.fact_collisions (
    collision_index        TEXT NOT NULL,
    collision_date         DATE NOT NULL,
    collision_time         TIME,
    road_type              SMALLINT,
    collision_severity     SMALLINT,
    number_of_vehicles     SMALLINT,
    number_of_casualties   SMALLINT,

    CONSTRAINT pk_fact_collisions
        PRIMARY KEY (collision_index)
);

INSERT INTO hw4.fact_collisions (
    collision_index,
    collision_date,
    collision_time,
    road_type,
    collision_severity,
    number_of_vehicles,
    number_of_casualties
)
SELECT
    collision_index,
    TO_DATE(collision_date, 'DD/MM/YYYY'),
    NULLIF(collision_time, '')::TIME,
    NULLIF(road_type, '')::SMALLINT,
    NULLIF(collision_severity, '')::SMALLINT,
    NULLIF(number_of_vehicles, '')::SMALLINT,
    NULLIF(number_of_casualties, '')::SMALLINT
FROM hw4.raw_collisions;

ANALYZE hw4.fact_collisions;

SELECT
    COUNT(*) AS rows_count,
    COUNT(DISTINCT collision_index) AS unique_collision_index,
    COUNT(*) - COUNT(collision_index) AS null_collision_index,
    MIN(collision_date) AS min_date,
    MAX(collision_date) AS max_date
FROM hw4.fact_collisions;