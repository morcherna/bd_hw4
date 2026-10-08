\# HW4 — Аналитическая витрина в ClickHouse



\## 1. Описание проекта



Домашнее задание 4 по курсу Data Engineering.



Предметная область — дорожная безопасность. Используется открытый набор данных \*\*Road Safety Data – Collisions – 2025\*\* Министерства транспорта Великобритании (UK Department for Transport).



Цель работы:



\* загрузить одинаковые данные в PostgreSQL и ClickHouse;

\* построить две версии таблицы ClickHouse с разными ключами сортировки;

\* сравнить планы и объём чтения для выборочного и широкого аналитического запросов;

\* построить incremental Materialized View;

\* проверить корректность исторических данных и нескольких последовательных поступлений данных;

\* исследовать ограничения повторной доставки;

\* зафиксировать результаты измерений и условия эксперимента.



\---



\## 2. Структура проекта



```text

student-Mukovozova-hw4/

├── docker-compose.yml

├── README.md

│

├── clickhouse/

│   └── init/

│       ├── 01\_load.sql

│       ├── 02\_variant\_road.sql

│       └── 03\_mart.sql

│

├── postgres/

│   └── init/

│       ├── 01\_load.sql

│       └── 02\_indexes.sql

│

├── data/

│   ├── hw4\_fact.csv

│   ├── new\_batch.csv

│   └── new\_batch\_2.csv

│

├── measurements/

│   ├── q1\_raw.csv

│   ├── q2\_raw.csv

│   └── summary.csv

│

├── sql/

│   ├── 01\_correctness.sql

│   ├── 02\_mv\_checks.sql

│   └── 03\_benchmarks.sql

│

├── report/

└── screenshots/

```



\---



\## 3. Источник данных



Источник:



\*\*Road Safety Data – Collisions – 2025\*\*, UK Department for Transport Road Safety Open Data.



Период данных:



```text

2025-01-01 — 2025-12-31

```



Исходный набор содержит:



```text

101525 collision records

44 columns

```



Бизнес-ключ:



```text

collision\_index

```



В исходном наборе:



```text

101525 строк

101525 уникальных collision\_index

0 NULL collision\_index

```



Данные являются открытыми. Лицензия источника — Open Government Licence v3.0.



\---



\## 4. Data Contract



\### Смысл одной строки



Одна строка представляет одну зарегистрированную дорожную аварию (collision), сообщённую полицией.



\### Бизнес-ключ



```text

collision\_index

```



Ключ однозначно идентифицирует аварию и используется для проверки уникальности.



\### Дата и время



Дата хранится в PostgreSQL как `DATE`.



Время хранится как `TIME`.



В ClickHouse дата хранится как `Date`, время — как строковое значение исходного времени.



В исходных данных дата представлена в формате:



```text

DD/MM/YYYY

```



Например:



```text

05/03/2025

```



После преобразования используется:



```text

2025-03-05

```



Часовой пояс явным образом не хранится в наборе. ClickHouse в эксперименте работает в:



```text

UTC

```



Время из исходного набора не преобразуется между часовыми поясами.



\### Метрики



Используются:



\* `number\_of\_vehicles` — количество транспортных средств;

\* `number\_of\_casualties` — количество пострадавших;

\* `collision\_severity` — код тяжести аварии;

\* `road\_type` — код типа дороги.



В рамках данной работы:



```text

collision\_severity = 2

```



считается серьёзной аварией для метрики `serious\_collisions`.



\### NULL



В PostgreSQL пустые значения исходного CSV загружаются как `NULL`.



При преобразовании числовых полей используется `NULLIF`.



Для агрегирования в ClickHouse:



```sql

sum(ifNull(number\_of\_vehicles, 0))

sum(ifNull(number\_of\_casualties, 0))

```



то есть отсутствующая числовая метрика не увеличивает сумму.



\### Отмены



В исходном наборе отсутствует отдельное понятие отменённой записи. Поэтому отдельная логика удаления отменённых событий не применяется.



\### Дубли



Бизнес-ключ `collision\_index` должен быть уникальным.



В PostgreSQL это дополнительно обеспечивается первичным ключом:



```text

PRIMARY KEY (collision\_index)

```



В ClickHouse уникальность контролируется проверками `uniqExact(collision\_index)` и бизнес-логикой загрузки.



ClickHouse MergeTree сам по себе не является уникальным хранилищем.



\### Исправления



Исправление существующей записи не реализуется как UPDATE в рамках данного эксперимента. Для production-сценария потребовалась бы отдельная стратегия версионирования или идемпотентной загрузки.



\---



\## 5. Используемые версии и ресурсы



Эксперимент выполнялся локально на Windows с Docker Desktop и Linux containers.



Используемые версии:



```text

PostgreSQL 16.15

ClickHouse 25.8.33.6

Docker Engine 29.7.2

Docker Compose 5.5.0

```



Ресурсы Docker:



```text

CPU: 16

Memory: \~15.15 GiB

```



ClickHouse:



```text

timezone: UTC

max\_threads: auto(16)

use\_query\_cache: 0

use\_uncompressed\_cache: 0

```



Query cache и uncompressed cache были отключены.



\---



\## 6. Запуск проекта



Перейти в каталог проекта:



```cmd

cd C:\\Users\\mukov\\Учеба\\student-Mukovozova-hw4

```



Запустить PostgreSQL и ClickHouse:



```cmd

docker compose up -d

```



Проверить состояние:



```cmd

docker compose ps

```



Должны работать контейнеры:



```text

hw4-postgres

hw4-clickhouse

```



\---



\## 7. Локальный путь к исходным данным



В `docker-compose.yml` используются абсолютные Windows-пути к исходному CSV из предыдущего проекта.



На другой машине этот путь необходимо заменить на путь к локальному файлу:



```text

source.csv

```



Используемый исходный файл:



```text

data/student\_Mukovozova/road\_safety/source.csv

```



На моей машине исходный путь:



```text

C:/Users/mukov/Учеба/student-Mukovozova-hw1/data/student\_Mukovozova/road\_safety/source.csv

```



При переносе проекта на другую машину необходимо изменить соответствующие volume paths в `docker-compose.yml`.



Пароли в проекте являются локальными учебными значениями и не относятся к реальным системам.



\---



\## 8. PostgreSQL



PostgreSQL используется как контрольная система для проверки корректности данных и выполнения сравнительного запроса.



Создаётся схема:



```text

hw4

```



Основные таблицы:



```text

hw4.raw\_collisions

hw4.fact\_collisions

```



Загрузка выполняется скриптом:



```text

postgres/init/01\_load.sql

```



Индексы создаются скриптом:



```text

postgres/init/02\_indexes.sql

```



Индексы:



```text

idx\_hw4\_fact\_date

&#x20;   (collision\_date)



idx\_hw4\_fact\_road\_date

&#x20;   (road\_type, collision\_date)

```



После загрузки выполняется:



```sql

ANALYZE hw4.fact\_collisions;

```



Таким образом, PostgreSQL использует актуальную статистику.



\---



\## 9. ClickHouse



Создаётся база:



```text

hw4

```



Используются две таблицы MergeTree с одинаковыми данными.



\### Вариант 1 — сортировка по дате



```text

hw4.fact\_collisions\_by\_date

```



Ключ:



```sql

ORDER BY (collision\_date, road\_type, collision\_index)

```



Этот вариант ориентирован прежде всего на запросы с фильтрацией по дате.



\### Вариант 2 — сортировка по типу дороги



```text

hw4.fact\_collisions\_by\_road

```



Ключ:



```sql

ORDER BY (road\_type, collision\_date, collision\_index)

```



Этот вариант выбран как альтернатива для аналитики, в которой первым измерением является тип дороги.



Обе таблицы содержат одинаковые строки.



\---



\## 10. Партиционирование



`PARTITION BY` намеренно не используется.



Причины:



\* весь основной набор относится к одному году — 2025;

\* размер набора составляет около 100 тысяч строк;

\* запросы работают с датой и типом дороги, поэтому сортировка уже позволяет использовать primary key condition;

\* дополнительное партиционирование по году для одного года не уменьшило бы объём работы;

\* создание большого количества мелких партиций для такого объёма данных увеличило бы административные накладные расходы и количество частей.



В данном эксперименте поэтому используется один набор MergeTree без явного `PARTITION BY`, а влияние организации данных исследуется через `ORDER BY`.



\---



\## 11. Incremental Materialized View



Создаётся целевая таблица:



```text

hw4.mart\_daily\_road

```



Тип:



```text

SummingMergeTree

```



Сортировка:



```sql

ORDER BY (collision\_date, road\_type)

```



Гранулярность витрины:



```text

день + тип дороги

```



Метрики:



```text

collisions\_count

vehicles\_count

casualties\_count

serious\_collisions

```



Materialized View:



```text

hw4.mv\_mart\_daily\_road

```



Источник:



```text

hw4.fact\_collisions\_by\_date

```



При поступлении новых строк MV автоматически создаёт агрегаты для соответствующих `(collision\_date, road\_type)`.



\---



\## 12. Исторические данные



Materialized View была создана после загрузки исторического набора.



Поэтому исторические данные в `mart\_daily\_road` были заполнены отдельной агрегацией.



Исторический результат:



```text

101525 collisions

183948 vehicles

127883 casualties

25191 serious collisions

```



Это позволяет использовать MV для новых поступлений, не рассчитывая исторические данные повторно.



\---



\## 13. Incremental batches



\### Batch #1



Первая новая пачка содержит 5 записей:



```text

+5 collisions

+9 vehicles

+11 casualties

+3 serious collisions

```



После её поступления:



```text

101530 collisions

183957 vehicles

127894 casualties

25194 serious collisions

```



\### Batch #2



Вторая независимая пачка содержит 3 записи:



```text

HW4NEW000006

HW4NEW000007

HW4NEW000008

```



Она добавляет:



```text

+3 collisions

+7 vehicles

+6 casualties

+1 serious collision

```



После двух последовательных пачек:



```text

101533 collisions

183964 vehicles

127900 casualties

25195 serious collisions

```



Таким образом, проверено последовательное объединение исторических данных и двух независимых batch.



\---



\## 14. Ограничение повторной доставки



Выбранная схема не является идемпотентной.



Если повторно вставить уже обработанный batch с теми же `collision\_index`, Materialized View повторно добавит его агрегаты.



Например, повторная доставка Batch #1 приведёт к дополнительному:



```text

+5 collisions

+9 vehicles

+11 casualties

+3 serious

```



Поэтому в production-системе требуется дополнительный механизм защиты от повторной доставки, например:



\* дедупликация по бизнес-ключу;

\* контроль batch ID;

\* staging-слой;

\* идемпотентный loader;

\* отдельная стратегия обработки исправлений.



В рамках учебного эксперимента повторная доставка намеренно не выполнялась, чтобы не загрязнять итоговый набор данных.



\---



\## 15. Проверка корректности



Проверялись:



\* количество строк;

\* уникальность `collision\_index`;

\* отсутствие NULL бизнес-ключей;

\* диапазон дат;

\* агрегаты по `road\_type`;

\* агрегаты по `collision\_severity`;

\* количество аварий;

\* количество транспортных средств;

\* количество пострадавших;

\* количество серьёзных аварий.



После Batch #1 и Batch #2 данные в PostgreSQL и ClickHouse совпадали по всем группам.



Для Q2 проверены все 17 комбинаций:



```text

road\_type × collision\_severity

```



Сравнивались не только количества строк, но и все три метрики:



```text

collisions

vehicles

casualties

```



SQL-проверки находятся в:



```text

sql/01\_correctness.sql

sql/02\_mv\_checks.sql

```



\---



\## 16. Профили запросов



Исследовались два профиля.



\### Q1 — выборочный запрос



Фильтр:



```sql

WHERE collision\_date = toDate('2025-03-05')

```



Метрики:



```text

collisions

vehicles

casualties

serious

```



Гипотеза:



> Сортировка по `collision\_date` должна уменьшить объём чтения для запроса по конкретной дате.



\### Q2 — широкий аналитический запрос



Группировка:



```sql

GROUP BY road\_type, collision\_severity

```



без фильтра по дате.



Гипотеза:



> При полном чтении набора преимущество конкретного сортировочного ключа должно уменьшиться или исчезнуть.



\---



\## 17. Q1 — планы ClickHouse



Для `fact\_collisions\_by\_date`:



```text

Parts: 2/2

Granules: 3/13

```



Для `fact\_collisions\_by\_road`:



```text

Parts: 2/2

Granules: 6/13

```



Вариант с сортировкой по дате прочитал существенно меньший объём данных.



Измеренные значения:



```text

by\_date:

read\_rows  = 16389

read\_bytes = 180279



by\_road:

read\_rows  = 44186

read\_bytes = 486046

```



Таким образом, date-first сортировка уменьшила чтение примерно в 2.7 раза.



\---



\## 18. Q2 — планы ClickHouse



Для обоих вариантов:



```text

Parts: 2/2

Granules: 13/13

```



Оба варианта читают весь набор.



Измерения:



```text

by\_date:

101530 rows

1116830 bytes



by\_road:

101530 rows

1116830 bytes

```



Таким образом, при широком запросе сортировочный ключ не позволяет исключить гранулы.



\---



\## 19. PostgreSQL планы



Для Q1 PostgreSQL использовал:



```text

Bitmap Heap Scan

Bitmap Index Scan

idx\_hw4\_fact\_date

```



Для Q2 использовался:



```text

Seq Scan

HashAggregate

Sort

```



Индекс для Q2 специально не навязывался, поскольку запрос требует агрегации всего набора данных.



PostgreSQL статистика обновлялась через:



```sql

ANALYZE hw4.fact\_collisions;

```



\---



\## 20. Методика измерений



Для каждого профиля выполнялись:



1\. прогрев;

2\. 5 измеряемых запусков;

3\. сохранение всех времён;

4\. расчёт minimum;

5\. расчёт median;

6\. расчёт maximum.



В ClickHouse использовался:



```text

system.query\_log

```



и поля:



```text

query\_duration\_ms

read\_rows

read\_bytes

```



В PostgreSQL использовался:



```sql

EXPLAIN (ANALYZE, BUFFERS, TIMING OFF)

```



с фиксацией `Execution Time` и buffer metrics.



Первый запуск после прогрева не включался в пять основных измерений.



\---



\## 21. Кэш и параллелизм



Измерения выполнялись после прогрева, поэтому результаты характеризуют состояние \*\*warm cache\*\*.



В ClickHouse:



```text

use\_query\_cache = 0

use\_uncompressed\_cache = 0

max\_threads = auto(16)

```



Фоновые операции MergeTree не отключались.



После двух новых batch состояние ClickHouse:



```text

fact\_collisions\_by\_date: 3 active parts

fact\_collisions\_by\_road: 3 active parts

mart\_daily\_road: 3 active parts

```



Это состояние было зафиксировано после загрузки второго batch.



\---



\## 22. Результаты измерений



\### Q1



| System     | Variant  | Min ms | Median ms | Max ms | Read rows | Read bytes |

| ---------- | -------- | -----: | --------: | -----: | --------: | ---------: |

| PostgreSQL | postgres |  0.614 |     0.734 |  0.830 |         — |          — |

| ClickHouse | by\_date  |      4 |         5 |      5 |     16389 |     180279 |

| ClickHouse | by\_road  |      4 |         4 |      7 |     44186 |     486046 |



\### Q2



| System     | Variant  | Min ms | Median ms | Max ms | Read rows | Read bytes |

| ---------- | -------- | -----: | --------: | -----: | --------: | ---------: |

| PostgreSQL | postgres | 13.402 |    14.101 | 14.463 |    101530 |          — |

| ClickHouse | by\_date  |      7 |         7 |      8 |    101530 |    1116830 |

| ClickHouse | by\_road  |      6 |         7 |      8 |    101530 |    1116830 |



Исходные измерения находятся в:



```text

measurements/q1\_raw.csv

measurements/q2\_raw.csv

measurements/summary.csv

```



Важно: прямое сравнение абсолютных миллисекунд PostgreSQL и ClickHouse следует интерпретировать осторожно, поскольку используются разные измерители и разные механизмы фиксации времени. Основной объект сравнения внутри ClickHouse — объём чтения и влияние сортировки, а PostgreSQL рассматривается как контрольная система.



\---



\## 23. Выводы



Основной результат эксперимента подтверждает зависимость эффективности ClickHouse от ключа сортировки.



Для выборочного запроса по дате вариант:



```sql

ORDER BY (collision\_date, road\_type, collision\_index)

```



оказался более подходящим.



Он уменьшил объём чтения:



```text

44 186 → 16 389 rows

486 046 → 180 279 bytes

```



и позволил исключить больше гранул:



```text

6/13 → 3/13

```



Для широкого запроса без фильтра оба варианта прочитали весь набор:



```text

101530 rows

1116830 bytes

13/13 granules

```



Поэтому для широкого запроса существенного преимущества одного ключа сортировки по объёму чтения нет.



Выбор сортировки должен определяться наиболее важными запросами, а не абстрактным правилом о том, какой ключ является «лучшим».



\---



\## 24. Ограничения эксперимента



Основные ограничения:



\* набор содержит около 100 тысяч строк, а не сотни миллионов;

\* эксперимент выполняется на одном локальном ClickHouse;

\* не исследуется распределённый MPP-кластер;

\* сравнение времени PostgreSQL и ClickHouse использует разные инструменты измерения;

\* измерения проводились на warm cache;

\* фоновые MergeTree merges не отключались;

\* выбранная Materialized View не обеспечивает идемпотентность повторной доставки.



Поэтому результаты характеризуют конкретное локальное окружение и не являются универсальным сравнением PostgreSQL и ClickHouse для всех объёмов данных.



\---



\## 25. Что произошло бы в MPP



В распределённом ClickHouse запросы с JOIN зависят от того, как данные распределены между узлами.



Если таблицы распределены по одному ключу JOIN, соответствующие строки могут находиться на одном узле, и стоимость JOIN уменьшается.



Если ключ распределения не совпадает с ключом JOIN, системе может потребоваться пересылка данных между узлами.



Это приводит к:



\* network shuffle;

\* дополнительной сетевой нагрузке;

\* росту времени JOIN;

\* увеличению объёма промежуточных данных.



Также возможен data skew.



Если большое количество строк имеет одно и то же значение ключа распределения, соответствующий shard получает непропорционально большую нагрузку, тогда как остальные узлы простаивают.



В данной работе MPP-кластер не разворачивается, поскольку по условию задания он не требуется.



\---



\## 26. Остановка окружения



Для остановки контейнеров без удаления данных:



```cmd

docker compose stop

```



Эта команда останавливает контейнеры, но сохраняет Docker volumes.



Не следует использовать:



```cmd

docker compose down -v

```



если требуется сохранить данные.



\---



\## 27. Полезные команды



Проверить контейнеры:



```cmd

docker compose ps

```



Подключиться к PostgreSQL:



```cmd

docker exec -it hw4-postgres psql -U dwh -d road\_safety\_hw4

```



Подключиться к ClickHouse:



```cmd

docker exec -it hw4-clickhouse clickhouse-client

```



Проверить ClickHouse:



```sql

SELECT version();

```



Проверить количество строк:



```sql

SELECT count()

FROM hw4.fact\_collisions\_by\_date;

```



Проверить Materialized View:



```sql

SELECT \*

FROM hw4.mart\_daily\_road

ORDER BY collision\_date, road\_type;

```



\---



\## 28. Файлы проекта



Основные SQL-файлы:



```text

postgres/init/01\_load.sql

postgres/init/02\_indexes.sql



clickhouse/init/01\_load.sql

clickhouse/init/02\_variant\_road.sql

clickhouse/init/03\_mart.sql



sql/01\_correctness.sql

sql/02\_mv\_checks.sql

sql/03\_benchmarks.sql

```



Исходные измерения:



```text

measurements/q1\_raw.csv

measurements/q2\_raw.csv

measurements/summary.csv

```



Тестовые batch:



```text

data/new\_batch.csv

data/new\_batch\_2.csv

```



\---



\## 29. Итог



В проекте реализованы:



\* локальный PostgreSQL;

\* локальный ClickHouse;

\* одинаковый набор данных;

\* проверка бизнес-ключа;

\* две альтернативные сортировки MergeTree;

\* анализ primary key pruning;

\* incremental Materialized View;

\* историческое заполнение витрины;

\* две последовательные новые пачки;

\* проверка агрегатов;

\* анализ повторной доставки;

\* выборочный и широкий профили запросов;

\* PostgreSQL индексы и актуальная статистика;

\* прогрев и пять измерений каждого варианта;

\* сохранение исходных результатов;

\* анализ чтения и планов;

\* обсуждение MPP JOIN и data skew.



Проект предназначен для воспроизводимого локального запуска в Docker Desktop.



