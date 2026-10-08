CREATE TABLE IF NOT EXISTS hw4.mart_daily_road
(
    collision_date       Date,
    road_type            Int16,
    collisions_count     UInt64,
    vehicles_count       UInt64,
    casualties_count     UInt64,
    serious_collisions   UInt64
)
ENGINE = SummingMergeTree
ORDER BY (collision_date, road_type);


CREATE MATERIALIZED VIEW IF NOT EXISTS hw4.mv_mart_daily_road
TO hw4.mart_daily_road
AS
SELECT
    collision_date,
    road_type,
    count() AS collisions_count,
    sum(ifNull(number_of_vehicles, 0)) AS vehicles_count,
    sum(ifNull(number_of_casualties, 0)) AS casualties_count,
    countIf(collision_severity = 2) AS serious_collisions
FROM hw4.fact_collisions_by_date
GROUP BY
    collision_date,
    road_type;