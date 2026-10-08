
SELECT
    count() AS collisions,
    sum(number_of_vehicles) AS vehicles,
    sum(number_of_casualties) AS casualties,
    countIf(collision_severity = 2) AS serious
FROM hw4.fact_collisions_by_date
WHERE collision_date = toDate('2025-03-05');


SELECT
    count() AS collisions,
    sum(number_of_vehicles) AS vehicles,
    sum(number_of_casualties) AS casualties,
    countIf(collision_severity = 2) AS serious
FROM hw4.fact_collisions_by_road
WHERE collision_date = toDate('2025-03-05');


-- Q2: wide analytical query
-- Reads the complete dataset because there is no selective filter.
SELECT
    road_type,
    collision_severity,
    count(*) AS collisions,
    sum(number_of_vehicles) AS vehicles,
    sum(number_of_casualties) AS casualties
FROM hw4.fact_collisions_by_date
GROUP BY road_type, collision_severity
ORDER BY road_type, collision_severity;


SELECT
    road_type,
    collision_severity,
    count(*) AS collisions,
    sum(number_of_vehicles) AS vehicles,
    sum(number_of_casualties) AS casualties
FROM hw4.fact_collisions_by_road
GROUP BY road_type, collision_severity
ORDER BY road_type, collision_severity;