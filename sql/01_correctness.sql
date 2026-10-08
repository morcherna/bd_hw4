-- 1. Row count and business-key uniqueness in PostgreSQL
SELECT
    COUNT(*) AS rows_count,
    COUNT(DISTINCT collision_index) AS unique_keys,
    COUNT(*) - COUNT(collision_index) AS null_keys,
    MIN(collision_date) AS min_date,
    MAX(collision_date) AS max_date
FROM hw4.fact_collisions;


-- 2. Row count and business-key uniqueness in ClickHouse, variant 1
SELECT
    count() AS rows_count,
    uniqExact(collision_index) AS unique_keys,
    countIf(collision_index = '') AS empty_keys,
    min(collision_date) AS min_date,
    max(collision_date) AS max_date
FROM hw4.fact_collisions_by_date;


-- 3. Row count and business-key uniqueness in ClickHouse, variant 2
SELECT
    count() AS rows_count,
    uniqExact(collision_index) AS unique_keys,
    countIf(collision_index = '') AS empty_keys,
    min(collision_date) AS min_date,
    max(collision_date) AS max_date
FROM hw4.fact_collisions_by_road;


-- 4. Detailed aggregation used for PostgreSQL / ClickHouse comparison
SELECT
    road_type,
    collision_severity,
    count() AS collisions,
    sum(ifNull(number_of_vehicles, 0)) AS vehicles,
    sum(ifNull(number_of_casualties, 0)) AS casualties
FROM hw4.fact_collisions_by_date
GROUP BY road_type, collision_severity
ORDER BY road_type, collision_severity;


-- 5. Second ClickHouse sorting variant:
-- the same metrics must produce the same 17 groups
SELECT
    road_type,
    collision_severity,
    count() AS collisions,
    sum(ifNull(number_of_vehicles, 0)) AS vehicles,
    sum(ifNull(number_of_casualties, 0)) AS casualties
FROM hw4.fact_collisions_by_road
GROUP BY road_type, collision_severity
ORDER BY road_type, collision_severity;