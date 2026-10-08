# HW4 — Аналитическая витрина в ClickHouse

## 1. Предметная область и исходные данные

В качестве предметной области выбрана дорожная безопасность.

**Источник данных:** Road Safety Data – Collisions – 2025, UK Department for Transport Road Safety Open Data.

**Период:**

```text
2025-01-01 — 2025-12-31
```

**Исходный набор содержит:**

```text
101525 записей
44 столбца
```

**Бизнес-ключ:** `collision_index`

**В исходном наборе проверено:**

```text
101525 строк
101525 уникальных collision_index
0 NULL collision_index
```

**Используемые поля аналитической модели:**

- `collision_index`
- `collision_date`
- `collision_time`
- `road_type`
- `collision_severity`
- `number_of_vehicles`
- `number_of_casualties`

Для аналитики серьёзных аварий используется условие `collision_severity = 2`.


## 2. Контракт данных

### 2.1. Смысл строки

Одна строка представляет одну зарегистрированную дорожную аварию.

### 2.2. Бизнес-ключ

Уникальный идентификатор аварии:

```text
collision_index
```

- В PostgreSQL он является первичным ключом.
- В ClickHouse уникальность проверяется отдельно, поскольку MergeTree не является уникальным хранилищем.

### 2.3. Дата и время

Дата преобразуется в тип `DATE` в PostgreSQL и `Date` в ClickHouse.

Исходный формат:

```text
DD/MM/YYYY
```

Например: `05/03/2025`

В модели: `2025-03-05`

ClickHouse работает в часовом поясе UTC. Временная зона не преобразуется, поскольку исходный набор не содержит отдельной timezone-информации.

### 2.4. NULL

Пустые значения исходного CSV преобразуются в `NULL`.

Для сумм в ClickHouse используется:

```sql
sum(ifNull(number_of_vehicles, 0))
sum(ifNull(number_of_casualties, 0))
```

### 2.5. Дубли

Основной ключ — `collision_index`.

В PostgreSQL уникальность обеспечивается:

```sql
PRIMARY KEY (collision_index)
```

В ClickHouse проверяется через:

```sql
uniqExact(collision_index)
```

### 2.6. Отмены и исправления

В исходном наборе нет отдельного механизма отмены события.

Исправление уже загруженной записи в рамках учебной модели не реализуется как UPDATE. Для production-системы потребовался бы отдельный механизм версионирования или идемпотентной загрузки.

## 3. Окружение

Эксперимент выполнен на Windows с Docker Desktop и Linux containers.

**Версии:**

```text
PostgreSQL 16.15
ClickHouse 25.8.33.6
Docker Engine 29.7.2
Docker Compose 5.5.0
```

**Выделенные Docker ресурсы:**

```text
16 CPU
~15.15 GiB RAM
```

**ClickHouse:**

```text
timezone = UTC
max_threads = auto(16)
use_query_cache = 0
use_uncompressed_cache = 0
```

Измерения проводились после прогрева, то есть в режиме **warm cache**.


## 4. Запуск окружения

Проект запускается через Docker Compose.

**Команда:**

```cmd
docker compose up -d
```

**Проверка:**

```cmd
docker compose ps
```

Ожидается работа:

```text
hw4-postgres
hw4-clickhouse
```

<img width="1276" height="130" alt="image" src="https://github.com/user-attachments/assets/efda07a7-c6f0-473c-878e-2b288bc0f6bf" />


## 5. PostgreSQL

PostgreSQL используется как контрольная система и дополнительная точка сравнения.

**Создаются таблицы:**

```text
hw4.raw_collisions
hw4.fact_collisions
```

**Файл загрузки:** `postgres/init/01_load.sql`

**Файл индексов:** `postgres/init/02_indexes.sql`

Используются индексы:

```sql
CREATE INDEX idx_hw4_fact_date
    ON hw4.fact_collisions (collision_date);

CREATE INDEX idx_hw4_fact_road_date
    ON hw4.fact_collisions (road_type, collision_date);
```

После загрузки выполняется:

```sql
ANALYZE hw4.fact_collisions;
```

Это позволяет PostgreSQL использовать актуальную статистику.


## 6. Проверка одинакового набора данных

После загрузки проверяется:

- количество строк;
- количество уникальных бизнес-ключей;
- отсутствие NULL бизнес-ключа;
- диапазон дат.

### Команда PostgreSQL

```cmd
docker exec hw4-postgres psql -U dwh -d road_safety_hw4 -c "SELECT COUNT(*) AS rows_count, COUNT(DISTINCT collision_index) AS unique_collision_index, COUNT(*) - COUNT(collision_index) AS null_collision_index, MIN(collision_date) AS min_date, MAX(collision_date) AS max_date FROM hw4.fact_collisions;"
```

Ожидаемый результат после исходной загрузки:

```text
101525
101525
0
2025-01-01
2025-12-31
```

После добавления двух новых batch в PostgreSQL итоговый набор составляет 101530 строк, поскольку новые batch использовались прежде всего для проверки incremental-поступления в ClickHouse.

### Команда ClickHouse

```cmd
docker exec hw4-clickhouse clickhouse-client --query "SELECT count() AS rows_count, uniqExact(collision_index) AS unique_keys, countIf(collision_index = '') AS empty_keys, min(collision_date) AS min_date, max(collision_date) AS max_date FROM hw4.fact_collisions_by_date FORMAT PrettyCompact"
```

После двух batch:

```text
101525
101525
0
2025-01-01
2025-12-31
```

<img width="1271" height="141" alt="image" src="https://github.com/user-attachments/assets/32ab0692-fb0a-42b5-a548-c3b1ed6fdc26" />
<img width="1266" height="89" alt="image" src="https://github.com/user-attachments/assets/8fde39c9-7a5d-427e-9d96-af2116e2ebf8" />


## 7. Две организации данных в ClickHouse

Использованы две таблицы MergeTree.

### Вариант A — date-first

```sql
ENGINE = MergeTree
ORDER BY (collision_date, road_type, collision_index)
```

Таблица: `hw4.fact_collisions_by_date`

**Гипотеза:** такой ключ должен лучше работать для запросов, которые выбирают данные за определённую дату.

### Вариант B — road-first

```sql
ENGINE = MergeTree
ORDER BY (road_type, collision_date, collision_index)
```

Таблица: `hw4.fact_collisions_by_road`

**Гипотеза:** такой ключ потенциально лучше соответствует запросам, в которых первым ограничением является тип дороги.


## 8. Почему не используется PARTITION BY

Партиционирование намеренно не используется.

**Причины:**

1. Основной набор относится к одному году.
2. Размер набора составляет около 100 тысяч строк.
3. Основные выборочные запросы используют дату.
4. `ORDER BY` уже позволяет эффективно исключать гранулы.
5. Партиционирование по году для одного года не даёт дополнительного pruning.
6. Дополнительное дробление небольшого учебного набора может увеличить количество мелких частей.

Поэтому эксперимент специально сфокусирован на влиянии `ORDER BY`.


## 9. Проверка влияния сортировки через EXPLAIN

### Q1 — выборочный запрос

```sql
SELECT
    count() AS collisions,
    sum(number_of_vehicles) AS vehicles,
    sum(number_of_casualties) AS casualties,
    countIf(collision_severity = 2) AS serious
FROM hw4.fact_collisions_by_date
WHERE collision_date = toDate('2025-03-05');
```

Для второго варианта используется аналогичный запрос с `hw4.fact_collisions_by_road`.

### EXPLAIN для date-first

```cmd
docker exec hw4-clickhouse clickhouse-client --query "EXPLAIN indexes = 1 SELECT count() AS collisions, sum(number_of_vehicles) AS vehicles, sum(number_of_casualties) AS casualties, countIf(collision_severity = 2) AS serious FROM hw4.fact_collisions_by_date WHERE collision_date = toDate('2025-03-05');"
```

Фактически получено:

```text
Parts: 2/2
Granules: 3/13
```

### EXPLAIN для road-first

```cmd
docker exec hw4-clickhouse clickhouse-client --query "EXPLAIN indexes = 1 SELECT count() AS collisions, sum(number_of_vehicles) AS vehicles, sum(number_of_casualties) AS casualties, countIf(collision_severity = 2) AS serious FROM hw4.fact_collisions_by_road WHERE collision_date = toDate('2025-03-05');"
```

Получено:

```text
Parts: 2/2
Granules: 6/13
```

<img width="1262" height="380" alt="image" src="https://github.com/user-attachments/assets/84f5766b-3ec0-4f56-81e6-5af7f6edf44d" />

<img width="1253" height="386" alt="image" src="https://github.com/user-attachments/assets/3e87d819-e546-4bca-bfbb-5c894ba18757" />


## 10. Корректность Q1

После Batch #1 для даты `2025-03-05` получено:

```text
collisions = 307
vehicles   = 563
casualties = 372
serious    = 79
```

Эти значения совпадают в PostgreSQL и обеих ClickHouse таблицах.


## 11. Q2 — широкий аналитический запрос

```sql
SELECT
    road_type,
    collision_severity,
    COUNT(*) AS collisions,
    SUM(number_of_vehicles) AS vehicles,
    SUM(number_of_casualties) AS casualties
FROM ...
GROUP BY road_type, collision_severity
ORDER BY road_type, collision_severity;
```

Запрос проверяет 17 комбинаций `road_type × collision_severity`.

Сравниваются не только количества строк, но и:

- collisions;
- vehicles;
- casualties.

Результаты совпадают для PostgreSQL и обеих ClickHouse таблиц.


## 12. EXPLAIN Q2

Для обоих ClickHouse вариантов:

```text
Parts: 2/2
Granules: 13/13
```

Таким образом, при отсутствии фильтра весь набор данных читается целиком.

<img width="1263" height="296" alt="image" src="https://github.com/user-attachments/assets/306dd659-85c1-4e28-b1f0-0878d8fb4456" />

<img width="1258" height="298" alt="image" src="https://github.com/user-attachments/assets/6ff68775-d3e7-4d75-b4fb-362f1737812f" />


## 13. PostgreSQL планы

### Q1

Для Q1 PostgreSQL использовал индекс `idx_hw4_fact_date`.

**План:**

```text
Bitmap Heap Scan
Bitmap Index Scan
```

Зафиксировано:

```text
Execution Time: 0.739 ms
```

**Команда:**

```cmd
docker exec hw4-postgres psql -U dwh -d road_safety_hw4 -c "EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) SELECT count(*) AS collisions, sum(number_of_vehicles) AS vehicles, sum(number_of_casualties) AS casualties, count(*) FILTER (WHERE collision_severity = 2) AS serious FROM hw4.fact_collisions WHERE collision_date = DATE '2025-03-05';"
```

<img width="1266" height="381" alt="image" src="https://github.com/user-attachments/assets/2ae1805e-cabd-4c2a-beb9-48e0d0285ee4" />


### Q2

Для Q2 PostgreSQL использовал:

```text
Seq Scan
HashAggregate
Sort
```

и получил:

```text
Execution Time: 14.098 ms
```

**Команда:**

```cmd
docker exec hw4-postgres psql -U dwh -d road_safety_hw4 -c "EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) SELECT road_type, collision_severity, COUNT(*) AS collisions, SUM(number_of_vehicles) AS vehicles, SUM(number_of_casualties) AS casualties FROM hw4.fact_collisions GROUP BY road_type, collision_severity ORDER BY road_type, collision_severity;"
```

<img width="1261" height="391" alt="image" src="https://github.com/user-attachments/assets/023bdc5a-cb5c-4520-b079-39fde7c5a993" />

## 14. Incremental Materialized View

**Целевая таблица:** `hw4.mart_daily_road`

**Тип:** `SummingMergeTree`

**Сортировка:**

```text
ORDER BY (collision_date, road_type)
```

**Материализованное представление:** `hw4.mv_mart_daily_road`

**Группировка:**

```text
collision_date
road_type
```

**Метрики:**

```text
collisions_count
vehicles_count
casualties_count
serious_collisions
```


## 15. Историческая загрузка витрины

Materialized View не выполняет автоматический backfill уже существовавших строк.

Поэтому исторические данные были заполнены отдельной агрегацией.

До новых batch:

```text
101525 collisions
183948 vehicles
127883 casualties
25191 serious
```

Это совпадает с полной агрегацией detail-таблицы.


## 16. Первая новая пачка

**Batch #1:**

```text
HW4NEW000001
HW4NEW000002
HW4NEW000003
HW4NEW000004
HW4NEW000005
```

Добавляет:

```text
5 collisions
9 vehicles
11 casualties
3 serious
```

После обработки:

```text
101530 collisions
183957 vehicles
127894 casualties
25194 serious
```

<img width="1276" height="72" alt="image" src="https://github.com/user-attachments/assets/3a4430aa-8be0-43d6-b830-1d9f12e84f4f" />

## 17. Вторая новая пачка

**Batch #2 содержит:**

```text
HW4NEW000006
HW4NEW000007
HW4NEW000008
```

**Добавляет:**

```text
3 collisions
7 vehicles
6 casualties
1 serious
```

**Проверка по batch:**

```text
2025-04-10 road 1:
1 collision
2 vehicles
1 casualty
0 serious

2025-04-10 road 6:
1 collision
4 vehicles
3 casualties
1 serious

2025-04-11 road 9:
1 collision
1 vehicle
2 casualties
0 serious
```

После двух batch:

```text
101533 collisions
183964 vehicles
127900 casualties
25195 serious
```

<img width="1264" height="83" alt="image" src="https://github.com/user-attachments/assets/deb81721-3212-4ea1-8632-a91f027b4a67" />


## 18. Проверка нескольких агрегатов Batch #2

**Команда:**

```cmd
docker exec hw4-clickhouse clickhouse-client --query "SELECT collision_date, road_type, count() AS collisions, sum(number_of_vehicles) AS vehicles, sum(number_of_casualties) AS casualties, countIf(collision_severity = 2) AS serious FROM hw4.fact_collisions_by_date WHERE collision_index IN ('HW4NEW000006','HW4NEW000007','HW4NEW000008') GROUP BY collision_date, road_type ORDER BY collision_date, road_type FORMAT PrettyCompact"
```

**Получен результат:**

```text
2025-04-10  1  1  2  1  0
2025-04-10  6  1  4  3  1
2025-04-11  9  1  1  2  0
```

Это подтверждает корректную агрегацию второй пачки.


## 19. Повторная доставка

Выбранная реализация **не является идемпотентной**.

Если повторно доставить уже обработанный `collision_index`, Materialized View повторно увеличит агрегаты.

Это является ограничением `SummingMergeTree + incremental MV`.

В учебном эксперименте повторная доставка намеренно не выполнялась, чтобы не изменять итоговый набор данных.

В production необходимо добавить дедупликацию или идемпотентный механизм загрузки.


## 20. Методика измерений

Для каждого варианта выполнялись:

- warmup;
- 5 измерений;
- сохранение каждого времени;
- расчёт min;
- расчёт median;
- расчёт max.

Исходные значения сохранены в:

```text
measurements/q1_raw.csv
measurements/q2_raw.csv
measurements/summary.csv
```


## 21. Q1 результаты

| Система | Вариант | Min, ms | Median, ms | Max, ms | Read rows | Read bytes |
|---|---|---:|---:|---:|---:|---:|
| PostgreSQL | postgres | 0.614 | 0.734 | 0.830 | — | — |
| ClickHouse | by_date | 4 | 5 | 5 | 16389 | 180279 |
| ClickHouse | by_road | 4 | 4 | 7 | 44186 | 486046 |

**Главный результат Q1:**

```text
by_date:
16389 rows
180279 bytes

by_road:
44186 rows
486046 bytes
```

Таким образом, date-first сортировка позволяет прочитать существенно меньше данных.

## 22. Q2 результаты

| Система | Вариант | Min, ms | Median, ms | Max, ms | Read rows | Read bytes |
|---|---|---:|---:|---:|---:|---:|
| PostgreSQL | postgres | 13.402 | 14.101 | 14.463 | 101530 | — |
| ClickHouse | by_date | 7 | 7 | 8 | 101530 | 1116830 |
| ClickHouse | by_road | 6 | 7 | 8 | 101530 | 1116830 |

Для Q2 оба ClickHouse варианта читают весь набор.

Разница между вариантами находится в пределах небольших колебаний измерения:

```text
median by_date = 7 ms
median by_road = 7 ms
```

Поэтому нельзя утверждать, что один из ключей существенно лучше другого для широкого запроса.


## 23. Почему результаты Q1 и Q2 отличаются

Q1 содержит селективный фильтр по дате. Поэтому ClickHouse может использовать порядок данных и исключить часть гранул.

В Q2 фильтра нет. Поэтому для получения полной агрегации необходимо прочитать весь набор.

Получается:

```text
Q1:
сортировка влияет на объём чтения

Q2:
сортировка практически не влияет на объём чтения
```

Именно поэтому ключ сортировки необходимо выбирать исходя из реального профиля запросов.


## 24. Cache, parallelism и background work

Измерения выполнялись после warmup.

В ClickHouse:

```text
use_query_cache = 0
use_uncompressed_cache = 0
max_threads = auto(16)
```

После загрузки двух batch:

```text
fact_collisions_by_date = 3 active parts
fact_collisions_by_road = 3 active parts
mart_daily_road = 3 active parts
```

Фоновые merges не отключались.

Следовательно, результаты относятся к конкретному состоянию локального ClickHouse и не являются результатом полностью изолированного benchmark-окружения.

## 25. Ограничения эксперимента

1. Набор содержит около 100 тысяч строк.
2. Эксперимент выполнялся на одном локальном ClickHouse.
3. MPP-кластер не разворачивался.
4. Измерения выполнены на warm cache.
5. Фоновые MergeTree merges не отключались.
6. PostgreSQL и ClickHouse использовали разные средства измерения времени.
7. Materialized View не является идемпотентной при повторной доставке.
8. Весь основной набор относится к одному году, поэтому partitioning не исследовался как отдельный фактор.


## 26. MPP: JOIN и перекос нагрузки

В распределённой MPP-системе таблица может быть распределена по нескольким узлам.

Если таблицы для JOIN распределены по одному ключу, связанные строки могут находиться на одном узле. Это уменьшает необходимость пересылки данных.

Если ключ распределения не совпадает с ключом JOIN, может потребоваться network shuffle. Это приводит к:

- дополнительному сетевому трафику;
- передаче промежуточных данных;
- росту latency;
- дополнительной нагрузке на узлы.

Другой риск — **data skew**. Если значительная доля строк имеет одно значение ключа распределения, один узел получает непропорционально большую нагрузку.

В данной работе MPP-кластер не разворачивается, поскольку это не требуется заданием.

Однако при переносе модели в распределённую систему ключ распределения следует выбирать с учётом наиболее частых JOIN и равномерности распределения данных.


## 27. Итоговые выводы

В работе были реализованы две альтернативные организации данных ClickHouse:

```text
by_date:
ORDER BY (collision_date, road_type, collision_index)

by_road:
ORDER BY (road_type, collision_date, collision_index)
```

Для выборочного запроса по дате date-first вариант показал явное преимущество по объёму чтения:

```text
44186 → 16389 rows
486046 → 180279 bytes
```

и по количеству прочитанных гранул:

```text
6/13 → 3/13
```

Для широкого аналитического запроса оба варианта прочитали:

```text
101530 rows
1116830 bytes
13/13 granules
```

Следовательно, сортировка должна выбираться на основании профиля запросов.

Incremental Materialized View корректно обработала:

```text
историю
   ↓
Batch #1
   ↓
Batch #2
```

Итог:

```text
101533 collisions
183964 vehicles
127900 casualties
25195 serious
```

совпадает с агрегацией detail-таблицы.

Основное ограничение реализации — отсутствие защиты от повторной доставки одинаковых бизнес-ключей.
