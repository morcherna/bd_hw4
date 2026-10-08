CREATE TABLE IF NOT EXISTS hw4.fact_collisions_by_road
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
ORDER BY (road_type, collision_date, collision_index);