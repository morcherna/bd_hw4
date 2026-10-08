

-- 1. Current total in detail table
SELECT
    count() AS collisions,
    sum(ifNull(number_of_vehicles, 0)) AS vehicles,
    sum(ifNull(number_of_casualties, 0)) AS casualties,
    countIf(collision_severity = 2) AS serious
FROM hw4.fact_collisions_by_date;


-- 2. Current total in the incremental mart
SELECT
    sum(collisions_count) AS collisions,
    sum(vehicles_count) AS vehicles,
    sum(casualties_count) AS casualties,
    sum(serious_collisions) AS serious
FROM hw4.mart_daily_road;


-- 3. Recalculate the mart from detail data.
-- The result must match the materialized view after SummingMergeTree aggregation.
SELECT
    collision_date,
    road_type,
    count() AS collisions,
    sum(ifNull(number_of_vehicles, 0)) AS vehicles,
    sum(ifNull(number_of_casualties, 0)) AS casualties,
    countIf(collision_severity = 2) AS serious
FROM hw4.fact_collisions_by_date
GROUP BY collision_date, road_type
ORDER BY collision_date, road_type;


-- 4. Explicit check of Batch #2
SELECT
    collision_date,
    road_type,
    count() AS collisions,
    sum(ifNull(number_of_vehicles, 0)) AS vehicles,
    sum(ifNull(number_of_casualties, 0)) AS casualties,
    countIf(collision_severity = 2) AS serious
FROM hw4.fact_collisions_by_date
WHERE collision_index IN (
    'HW4NEW000006',
    'HW4NEW000007',
    'HW4NEW000008'
)
GROUP BY collision_date, road_type
ORDER BY collision_date, road_type;