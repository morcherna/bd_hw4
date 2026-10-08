1\. Предметная область и исходные данные



В качестве предметной области выбрана дорожная безопасность.



Источник данных:



\*\*Road Safety Data – Collisions – 2025\*\*, UK Department for Transport Road Safety Open Data.



Период:



```text

2025-01-01 — 2025-12-31

```



Исходный набор содержит:



```text

101525 записей

44 столбца

```



Бизнес-ключ:



```text

collision\_index

```



В исходном наборе проверено:



```text

101525 строк

101525 уникальных collision\_index

0 NULL collision\_index

```



Используемые поля аналитической модели:



\* `collision\_index`;

\* `collision\_date`;

\* `collision\_time`;

\* `road\_type`;

\* `collision\_severity`;

\* `number\_of\_vehicles`;

\* `number\_of\_casualties`.



Для аналитики серьёзных аварий используется условие:



```text

collision\_severity = 2

```



\---



\# 2. Контракт данных



\## 2.1. Смысл строки



Одна строка представляет одну зарегистрированную дорожную аварию.



\## 2.2. Бизнес-ключ



Уникальный идентификатор аварии:



```text

collision\_index

```



В PostgreSQL он является первичным ключом.



В ClickHouse уникальность проверяется отдельно, поскольку MergeTree не является уникальным хранилищем.



\## 2.3. Дата и время



Дата преобразуется в тип `DATE` в PostgreSQL и `Date` в ClickHouse.



Исходный формат:



```text

DD/MM/YYYY

```



Например:



```text

05/03/2025

```



В модели:



```text

2025-03-05

```



ClickHouse работает в часовом поясе UTC.



Временная зона не преобразуется, поскольку исходный набор не содержит отдельной timezone-информации.



\## 2.4. NULL



Пустые значения исходного CSV преобразуются в `NULL`.



Для сумм в ClickHouse используется:



```sql

sum(ifNull(number\_of\_vehicles, 0))

sum(ifNull(number\_of\_casualties, 0))

```





\## 2.5. Дубли



Основной ключ — `collision\_index`.



В PostgreSQL уникальность обеспечивается:



```sql

PRIMARY KEY (collision\_index)

```



В ClickHouse проверяется через:



```sql

uniqExact(collision\_index)

```



\## 2.6. Отмены и исправления



В исходном наборе нет отдельного механизма отмены события.



Исправление уже загруженной записи в рамках учебной модели не реализуется как UPDATE. Для production-системы потребовался бы отдельный механизм версионирования или идемпотентной загрузки.



\---



\# 3. Окружение



Эксперимент выполнен на Windows с Docker Desktop и Linux containers.



Версии:



```text

PostgreSQL 16.15

ClickHouse 25.8.33.6

Docker Engine 29.7.2

Docker Compose 5.5.0

```



Выделенные Docker ресурсы:



```text

16 CPU

\~15.15 GiB RAM

```



ClickHouse:



```text

timezone = UTC

max\_threads = auto(16)

use\_query\_cache = 0

use\_uncompressed\_cache = 0

```



Измерения проводились после прогрева, то есть в режиме warm cache.



\---



\# 4. Запуск окружения



Проект запускается через Docker Compose.



Команда:



```cmd

docker compose up -d

```



Проверка:



```cmd

docker compose ps

```



Ожидается работа:



```text

hw4-postgres

hw4-clickhouse

```



\## Скриншот 1 — работающее окружение



Выполнить:



```cmd

docker compose ps

```



\*\*Что должно быть видно на скриншоте:\*\*



\* `hw4-postgres`;

\* `hw4-clickhouse`;

\* статус `Up`/`running`;

\* порты.



Этот скриншот подтверждает локальный Docker-запуск.



\---



\# 6. PostgreSQL



PostgreSQL используется как контрольная система и дополнительная точка сравнения.



Создаются:



```text

hw4.raw\_collisions

hw4.fact\_collisions

```



Файл загрузки:



```text

postgres/init/01\_load.sql

```



Индексы:



```text

postgres/init/02\_indexes.sql

```



Используются индексы:



```sql

CREATE INDEX idx\_hw4\_fact\_date

&#x20;   ON hw4.fact\_collisions (collision\_date);



CREATE INDEX idx\_hw4\_fact\_road\_date

&#x20;   ON hw4.fact\_collisions (road\_type, collision\_date);

```



После загрузки выполняется:



```sql

ANALYZE hw4.fact\_collisions;

```



Это позволяет PostgreSQL использовать актуальную статистику.



\---



\# 7. Проверка одинакового набора данных



После загрузки проверяется:



\* количество строк;

\* количество уникальных бизнес-ключей;

\* отсутствие NULL бизнес-ключа;

\* диапазон дат.



\## Команда PostgreSQL



```cmd

docker exec hw4-postgres psql -U dwh -d road\_safety\_hw4 -c "SELECT COUNT(\*) AS rows\_count, COUNT(DISTINCT collision\_index) AS unique\_collision\_index, COUNT(\*) - COUNT(collision\_index) AS null\_collision\_index, MIN(collision\_date) AS min\_date, MAX(collision\_date) AS max\_date FROM hw4.fact\_collisions;"

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



\## Команда ClickHouse



```cmd

docker exec hw4-clickhouse clickhouse-client --query "SELECT count() AS rows\_count, uniqExact(collision\_index) AS unique\_keys, countIf(collision\_index = '') AS empty\_keys, min(collision\_date) AS min\_date, max(collision\_date) AS max\_date FROM hw4.fact\_collisions\_by\_date FORMAT PrettyCompact"

```



После двух batch:



```text

101533

101533

0

2025-01-01

2025-12-31

```



\## Скриншот 2 — проверка количества и уникальности



Для наглядности можно сделать \*\*один скриншот\*\*, где последовательно показаны команды PostgreSQL и ClickHouse и их результаты.



На скриншоте должны читаться:



```text

rows\_count

unique key count

null/empty key count

min\_date

max\_date

```



\---



\# 8. Две организации данных в ClickHouse



Использованы две таблицы MergeTree.



\## Вариант A — date-first



```sql

ENGINE = MergeTree

ORDER BY (collision\_date, road\_type, collision\_index)

```



Таблица:



```text

hw4.fact\_collisions\_by\_date

```



Гипотеза:



> Такой ключ должен лучше работать для запросов, которые выбирают данные за определённую дату.



\## Вариант B — road-first



```sql

ENGINE = MergeTree

ORDER BY (road\_type, collision\_date, collision\_index)

```



Таблица:



```text

hw4.fact\_collisions\_by\_road

```



Гипотеза:



> Такой ключ потенциально лучше соответствует запросам, в которых первым ограничением является тип дороги.



\---



\# 9. Почему не используется PARTITION BY



Партиционирование намеренно не используется.



Причины:



1\. Основной набор относится к одному году.

2\. Размер набора составляет около 100 тысяч строк.

3\. Основные выборочные запросы используют дату.

4\. `ORDER BY` уже позволяет эффективно исключать гранулы.

5\. Партиционирование по году для одного года не даёт дополнительного pruning.

6\. Дополнительное дробление небольшого учебного набора может увеличить количество мелких частей.



Поэтому эксперимент специально сфокусирован на влиянии `ORDER BY`.



\---



\# 10. Проверка влияния сортировки через EXPLAIN



\## Q1 — выборочный запрос



Запрос:



```sql

SELECT

&#x20;   count() AS collisions,

&#x20;   sum(number\_of\_vehicles) AS vehicles,

&#x20;   sum(number\_of\_casualties) AS casualties,

&#x20;   countIf(collision\_severity = 2) AS serious

FROM hw4.fact\_collisions\_by\_date

WHERE collision\_date = toDate('2025-03-05');

```



Для второго варианта используется аналогичный запрос с:



```text

hw4.fact\_collisions\_by\_road

```



\## EXPLAIN для date-first



Команда:



```cmd

docker exec hw4-clickhouse clickhouse-client --query "EXPLAIN indexes = 1 SELECT count() AS collisions, sum(number\_of\_vehicles) AS vehicles, sum(number\_of\_casualties) AS casualties, countIf(collision\_severity = 2) AS serious FROM hw4.fact\_collisions\_by\_date WHERE collision\_date = toDate('2025-03-05');"

```



Фактически получено:



```text

Parts: 2/2

Granules: 3/13

```



\## EXPLAIN для road-first



Команда:



```cmd

docker exec hw4-clickhouse clickhouse-client --query "EXPLAIN indexes = 1 SELECT count() AS collisions, sum(number\_of\_vehicles) AS vehicles, sum(number\_of\_casualties) AS casualties, countIf(collision\_severity = 2) AS serious FROM hw4.fact\_collisions\_by\_road WHERE collision\_date = toDate('2025-03-05');"

```



Получено:



```text

Parts: 2/2

Granules: 6/13

```



\## Скриншот 3 — ClickHouse EXPLAIN Q1



Сделать два скриншота:



\*\*3A:\*\*



```cmd

docker exec hw4-clickhouse clickhouse-client --query "EXPLAIN indexes = 1 SELECT count() AS collisions, sum(number\_of\_vehicles) AS vehicles, sum(number\_of\_casualties) AS casualties, countIf(collision\_severity = 2) AS serious FROM hw4.fact\_collisions\_by\_date WHERE collision\_date = toDate('2025-03-05');"

```



\*\*3B:\*\*



```cmd

docker exec hw4-clickhouse clickhouse-client --query "EXPLAIN indexes = 1 SELECT count() AS collisions, sum(number\_of\_vehicles) AS vehicles, sum(number\_of\_casualties) AS casualties, countIf(collision\_severity = 2) AS serious FROM hw4.fact\_collisions\_by\_road WHERE collision\_date = toDate('2025-03-05');"

```



На скриншотах должны быть читаемы:



```text

PrimaryKey

Parts

Granules

Condition

```



\---



\# 11. Корректность Q1



После Batch #1 для даты `2025-03-05` получено:



```text

collisions = 307

vehicles   = 563

casualties = 372

serious    = 79

```



Эти значения совпадают в PostgreSQL и обеих ClickHouse таблицах.



\---



\# 12. Q2 — широкий аналитический запрос



Запрос:



```sql

SELECT

&#x20;   road\_type,

&#x20;   collision\_severity,

&#x20;   COUNT(\*) AS collisions,

&#x20;   SUM(number\_of\_vehicles) AS vehicles,

&#x20;   SUM(number\_of\_casualties) AS casualties

FROM ...

GROUP BY road\_type, collision\_severity

ORDER BY road\_type, collision\_severity;

```



Запрос проверяет 17 комбинаций:



```text

road\_type × collision\_severity

```



Сравниваются не только количества строк, но и:



\* collisions;

\* vehicles;

\* casualties.



Результаты совпадают для PostgreSQL и обеих ClickHouse таблиц.



\---



\# 13. EXPLAIN Q2



Для обоих ClickHouse вариантов:



```text

Parts: 2/2

Granules: 13/13

```



Таким образом, при отсутствии фильтра весь набор данных читается целиком.



\## Скриншот 4 — ClickHouse EXPLAIN Q2



Выполнить:



```cmd

docker exec hw4-clickhouse clickhouse-client --query "EXPLAIN indexes = 1 SELECT road\_type, collision\_severity, COUNT(\*) AS collisions, SUM(number\_of\_vehicles) AS vehicles, SUM(number\_of\_casualties) AS casualties FROM hw4.fact\_collisions\_by\_date GROUP BY road\_type, collision\_severity ORDER BY road\_type, collision\_severity;"

```



И отдельно:



```cmd

docker exec hw4-clickhouse clickhouse-client --query "EXPLAIN indexes = 1 SELECT road\_type, collision\_severity, COUNT(\*) AS collisions, SUM(number\_of\_vehicles) AS vehicles, SUM(number\_of\_casualties) AS casualties FROM hw4.fact\_collisions\_by\_road GROUP BY road\_type, collision\_severity ORDER BY road\_type, collision\_severity;"

```



На скриншоте должны читаться:



```text

Parts: 2/2

Granules: 13/13

```



\---



\# 14. PostgreSQL планы



Для Q1 PostgreSQL использовал индекс:



```text

idx\_hw4\_fact\_date

```



План:



```text

Bitmap Heap Scan

Bitmap Index Scan

```



Зафиксировано:



```text

Execution Time: 0.739 ms

```



\## Команда



```cmd

docker exec hw4-postgres psql -U dwh -d road\_safety\_hw4 -c "EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) SELECT count(\*) AS collisions, sum(number\_of\_vehicles) AS vehicles, sum(number\_of\_casualties) AS casualties, count(\*) FILTER (WHERE collision\_severity = 2) AS serious FROM hw4.fact\_collisions WHERE collision\_date = DATE '2025-03-05';"

```



\## Скриншот 5 — PostgreSQL Q1 plan



На скриншоте должны быть видны:



```text

Bitmap Index Scan

idx\_hw4\_fact\_date

Bitmap Heap Scan

Buffers

Execution Time

```



\---



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



\## Команда



```cmd

docker exec hw4-postgres psql -U dwh -d road\_safety\_hw4 -c "EXPLAIN (ANALYZE, BUFFERS, TIMING OFF) SELECT road\_type, collision\_severity, COUNT(\*) AS collisions, SUM(number\_of\_vehicles) AS vehicles, SUM(number\_of\_casualties) AS casualties FROM hw4.fact\_collisions GROUP BY road\_type, collision\_severity ORDER BY road\_type, collision\_severity;"

```



\## Скриншот 6 — PostgreSQL Q2 plan



На скриншоте должны читаться:



```text

Seq Scan

HashAggregate

Sort

Buffers

Execution Time

```



\---



\# 15. Incremental Materialized View



Целевая таблица:



```text

hw4.mart\_daily\_road

```



Тип:



```text

SummingMergeTree

```



Сортировка:



```text

ORDER BY (collision\_date, road\_type)

```



Материализованное представление:



```text

hw4.mv\_mart\_daily\_road

```



Группировка:



```text

collision\_date

road\_type

```



Метрики:



```text

collisions\_count

vehicles\_count

casualties\_count

serious\_collisions

```



\---



\# 16. Историческая загрузка витрины



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



\---



\# 17. Первая новая пачка



Batch #1:



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



\## Скриншот 7 — первая пачка и обновление MV



Команда проверки:



```cmd

docker exec hw4-clickhouse clickhouse-client --query "SELECT sum(collisions\_count) AS collisions, sum(vehicles\_count) AS vehicles, sum(casualties\_count) AS casualties, sum(serious\_collisions) AS serious FROM hw4.mart\_daily\_road"

```



На скриншоте желательно показать:



1\. команду загрузки Batch #1;

2\. результат;

3\. итоговую агрегацию MV.



\---



\# 18. Вторая новая пачка



Batch #2 содержит:



```text

HW4NEW000006

HW4NEW000007

HW4NEW000008

```



Добавляет:



```text

3 collisions

7 vehicles

6 casualties

1 serious

```



Проверка по batch:



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



\## Скриншот 8 — вторая пачка и объединённый результат



Выполнить:



```cmd

docker exec hw4-clickhouse clickhouse-client --query "SELECT count() AS collisions, sum(number\_of\_vehicles) AS vehicles, sum(number\_of\_casualties) AS casualties, countIf(collision\_severity = 2) AS serious FROM hw4.fact\_collisions\_by\_date"

```



Затем:



```cmd

docker exec hw4-clickhouse clickhouse-client --query "SELECT sum(collisions\_count) AS collisions, sum(vehicles\_count) AS vehicles, sum(casualties\_count) AS casualties, sum(serious\_collisions) AS serious FROM hw4.mart\_daily\_road"

```



На скриншоте должны быть видны одинаковые итоговые значения:



```text

101533

183964

127900

25195

```



Это наиболее важный скриншот для доказательства корректности incremental MV.



\---



\# 19. Проверка нескольких агрегатов Batch #2



Команда:



```cmd

docker exec hw4-clickhouse clickhouse-client --query "SELECT collision\_date, road\_type, count() AS collisions, sum(number\_of\_vehicles) AS vehicles, sum(number\_of\_casualties) AS casualties, countIf(collision\_severity = 2) AS serious FROM hw4.fact\_collisions\_by\_date WHERE collision\_index IN ('HW4NEW000006','HW4NEW000007','HW4NEW000008') GROUP BY collision\_date, road\_type ORDER BY collision\_date, road\_type FORMAT PrettyCompact"

```



Получен результат:



```text

2025-04-10  1  1  2  1  0

2025-04-10  6  1  4  3  1

2025-04-11  9  1  1  2  0

```



Это подтверждает корректную агрегацию второй пачки.



\---



\# 20. Повторная доставка



Выбранная реализация не является идемпотентной.



Если повторно доставить уже обработанный `collision\_index`, Materialized View повторно увеличит агрегаты.



Это является ограничением `SummingMergeTree + incremental MV`.



В учебном эксперименте повторная доставка намеренно не выполнялась, чтобы не изменять итоговый набор данных.



В production необходимо добавить дедупликацию или идемпотентный механизм загрузки.



\---



\# 21. Методика измерений



Для каждого варианта выполнялись:



\* warmup;

\* 5 измерений;

\* сохранение каждого времени;

\* расчёт min;

\* расчёт median;

\* расчёт max.



Исходные значения сохранены в:



```text

measurements/q1\_raw.csv

measurements/q2\_raw.csv

measurements/summary.csv

```



\---



\# 22. Q1 результаты



| Система    | Вариант  | Min, ms | Median, ms | Max, ms | Read rows | Read bytes |

| ---------- | -------- | ------: | ---------: | ------: | --------: | ---------: |

| PostgreSQL | postgres |   0.614 |      0.734 |   0.830 |         — |          — |

| ClickHouse | by\_date  |       4 |          5 |       5 |     16389 |     180279 |

| ClickHouse | by\_road  |       4 |          4 |       7 |     44186 |     486046 |



Главный результат Q1:



```text

by\_date:

16389 rows

180279 bytes



by\_road:

44186 rows

486046 bytes

```



Таким образом, date-first сортировка позволяет прочитать существенно меньше данных.



\---



\# 23. Q2 результаты



| Система    | Вариант  | Min, ms | Median, ms | Max, ms | Read rows | Read bytes |

| ---------- | -------- | ------: | ---------: | ------: | --------: | ---------: |

| PostgreSQL | postgres |  13.402 |     14.101 |  14.463 |    101530 |          — |

| ClickHouse | by\_date  |       7 |          7 |       8 |    101530 |    1116830 |

| ClickHouse | by\_road  |       6 |          7 |       8 |    101530 |    1116830 |



Для Q2 оба ClickHouse варианта читают весь набор.



Разница между вариантами находится в пределах небольших колебаний измерения:



```text

median by\_date = 7 ms

median by\_road = 7 ms

```



Поэтому нельзя утверждать, что один из ключей существенно лучше другого для широкого запроса.



\---



\# 24. Почему результаты Q1 и Q2 отличаются



Q1 содержит селективный фильтр по дате.



Поэтому ClickHouse может использовать порядок данных и исключить часть гранул.



В Q2 фильтра нет.



Поэтому для получения полной агрегации необходимо прочитать весь набор.



Получается:



```text

Q1:

сортировка влияет на объём чтения



Q2:

сортировка практически не влияет на объём чтения

```



Именно поэтому ключ сортировки необходимо выбирать исходя из реального профиля запросов.



\---



\# 25. Cache, parallelism и background work



Измерения выполнялись после warmup.



В ClickHouse:



```text

use\_query\_cache = 0

use\_uncompressed\_cache = 0

max\_threads = auto(16)

```



После загрузки двух batch:



```text

fact\_collisions\_by\_date = 3 active parts

fact\_collisions\_by\_road = 3 active parts

mart\_daily\_road = 3 active parts

```



Фоновые merges не отключались.



Следовательно, результаты относятся к конкретному состоянию локального ClickHouse и не являются результатом полностью изолированного benchmark-окружения.



\---



\# 26. Ограничения эксперимента



1\. Набор содержит около 100 тысяч строк.

2\. Эксперимент выполнялся на одном локальном ClickHouse.

3\. MPP-кластер не разворачивался.

4\. Измерения выполнены на warm cache.

5\. Фоновые MergeTree merges не отключались.

6\. PostgreSQL и ClickHouse использовали разные средства измерения времени.

7\. Materialized View не является идемпотентной при повторной доставке.

8\. Весь основной набор относится к одному году, поэтому partitioning не исследовался как отдельный фактор.



\---



\# 27. MPP: JOIN и перекос нагрузки



В распределённой MPP-системе таблица может быть распределена по нескольким узлам.



Если таблицы для JOIN распределены по одному ключу, связанные строки могут находиться на одном узле.



Это уменьшает необходимость пересылки данных.



Если ключ распределения не совпадает с ключом JOIN, может потребоваться network shuffle.



Это приводит к:



\* дополнительному сетевому трафику;

\* передаче промежуточных данных;

\* росту latency;

\* дополнительной нагрузке на узлы.



Другой риск — data skew.



Если значительная доля строк имеет одно значение ключа распределения, один узел получает непропорционально большую нагрузку.



В данной работе MPP-кластер не разворачивается, поскольку это не требуется заданием.



Однако при переносе модели в распределённую систему ключ распределения следует выбирать с учётом наиболее частых JOIN и равномерности распределения данных.



\---



\# 28. Итоговые выводы



В работе были реализованы две альтернативные организации данных ClickHouse:



```text

by\_date:

ORDER BY (collision\_date, road\_type, collision\_index)



by\_road:

ORDER BY (road\_type, collision\_date, collision\_index)

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

&#x20;   ↓

Batch #1

&#x20;   ↓

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



\---



\# 29. Команда остановки



Для остановки окружения без удаления данных:



```cmd

docker compose stop

```



Docker volumes при этом сохраняются.



Команда:



```cmd

docker compose down -v

```



не используется, поскольку она удаляет volumes и данные эксперимента.



