CREATE DATABASE IF NOT EXISTS hw4;

DROP TABLE IF EXISTS hw4.fact_collisions_by_date;

CREATE TABLE hw4.fact_collisions_by_date
(
    collision_index      String,
    collision_date       Date,
    collision_time       String,
    road_type            Int16,
    collision_severity   Nullable(Int16),
    number_of_vehicles   Nullable(Int16),
    number_of_casualties Nullable(Int16)
)
ENGINE = MergeTree
ORDER BY (collision_date, road_type, collision_index);