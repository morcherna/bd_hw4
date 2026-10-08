CREATE INDEX IF NOT EXISTS idx_hw4_fact_date
    ON hw4.fact_collisions (collision_date);

CREATE INDEX IF NOT EXISTS idx_hw4_fact_road_date
    ON hw4.fact_collisions (road_type, collision_date);

ANALYZE hw4.fact_collisions;