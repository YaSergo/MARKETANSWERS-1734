set start_date='2016-11-10';
set end_date=  '2016-11-10';
set n_groups=   20;

DROP VIEW IF EXISTS medintsev.ma1734_access;
CREATE VIEW medintsev.ma1734_access AS
SELECT -- сколько просмотров конкретных страниц КМ было у определённого пользователя + раздаётся случайная группа
  yandexuid,
  page_groupid_2 as hyper_id,
  -- случайное определение группы
  INT(SUBSTR(yandexuid, 1, 7)) % ${hiveconf:n_groups} AS user_group,
  COUNT(*) AS n_shows
FROM
(
  SELECT -- оставляем только КМ и проставляем page_groupid_2
    yandexuid,
    -- термин page_groupid_2 используется в рамках задачи:
    -- https://st.yandex-team.ru/MARKETANSWERS-1587
    CASE
      WHEN regexp_extract(request_path, '^/product.*/\\d+', 0) <> ''
        THEN regexp_extract(request_path, '^/product.*/(\\d+)', 1)
      ELSE 0
    END as page_groupid_2
  FROM 
  (
    SELECT -- выгрузка из front_access с нужными условиями
      yandexuid,
      parse_url(concat('https://market.yandex.ru', request), 'PATH') as request_path
    FROM robot_market_logs.front_access
    WHERE
      day BETWEEN ${hiveconf:start_date} AND ${hiveconf:end_date}
      AND yandexuid IS NOT NULL
      AND status = '200' -- страница загружена без ошибок
      AND nvl(instr(vhost, 'market.yandex.'), 0) <> 0 -- только desktop
      -- в рамках данной задачи не критично, но лучше было бы исключить ещё данные о сотрудниках яндекса
  ) a
  WHERE
    -- это означет, что это КМ (т.е. page_groupid_1 = 1)
    regexp_extract(request_path, '^/product.*/\\d+', 0) <> ''
    -- удалось вытащить id КМ и он не ноль
    AND regexp_extract(request_path, '^/product.*/(\\d+)', 1) > 0
) b
GROUP BY
  yandexuid,
  page_groupid_2;

DROP VIEW IF EXISTS medintsev.ma1734_cpc_clicks;
CREATE VIEW medintsev.ma1734_cpc_clicks AS
SELECT
  yandexuid,
  hyper_id,
  SUM(price) AS cpc_price -- в рублях!
FROM
(
  SELECT
    cookie as yandexuid,
    hyper_id,
    price*30/100 as price -- в рублях
  FROM robot_market_logs.clicks
  WHERE
    day BETWEEN ${hiveconf:start_date} AND ${hiveconf:end_date}
    AND nvl(filter, 0) = 0 -- не накрутка
    AND state = 1 -- убираем клики сотрудников яндекса
    -- выяснить почему такое может быть:
    AND nvl(cookie, '') <> ''
    AND hyper_id > 0
    -- desktop КМ
    AND pp IN (6, 61, 62, 63, 64, 13, 21, 200, 201, 205, 206, 207, 208, 209, 210, 211, 26, 27, 144)
) a
GROUP BY
  yandexuid,
  hyper_id;

DROP VIEW IF EXISTS medintsev.ma1734_cpa_clicks;
CREATE VIEW medintsev.ma1734_cpa_clicks AS
SELECT
      yandexuid,
      hyper_id,
      sum(price) AS cpa_price
    FROM
    (
      SELECT
        cookie AS yandexuid,              -- кука yandexuid или пустое значение
        hyper_id,
        -- 0.05 оценочное значение, после запуска https://paste.yandex-team.ru/170192
        -- https://st.yandex-team.ru/MARKETANSWERS-1587#1477662737000
        offer_price*fee*0.05 AS price  -- в рублях
      FROM robot_market_logs.cpa_clicks
      WHERE
        day BETWEEN ${hiveconf:start_date} AND ${hiveconf:end_date}
        AND nvl(filter, 0) = 0 -- убираем накрутку
        AND state = 1 -- исклчаем сотрудников яндекса
        AND nvl(type_id, 0) = 0 -- 0 - нормальный cpa-click, 2 - показ карточки offera
        AND nvl(cookie, '') <> ''
        AND hyper_id > 0
        -- desktop КМ
        AND pp IN (6, 61, 62, 63, 64, 13, 21, 200, 201, 205, 206, 207, 208, 209, 210, 211, 26, 27, 144)
    ) a
    GROUP BY
      yandexuid,
      hyper_id;

SELECT
  ${hiveconf:start_date} AS start_date,
  ${hiveconf:end_date} AS end_date,

  hyper_id,
  AVG(cpm) AS cpm_avg, -- в рублях за один показ
  COUNT(*) AS n,
  STDDEV_SAMP(cpm) AS sd,
  collect_list(cpm) AS cpm_array -- для отладки
FROM
(
  SELECT
    ma1734_access.hyper_id,
    ma1734_access.user_group,
    (sum(nvl(cpa_price, 0)) + sum(nvl(cpc_price, 0))) / sum(n_shows) AS cpm
  FROM
    medintsev.ma1734_access LEFT JOIN
    (
      SELECT
        nvl(ma1734_cpc_clicks.yandexuid, ma1734_cpa_clicks.yandexuid) AS yandexuid,
        nvl(ma1734_cpc_clicks.hyper_id, ma1734_cpa_clicks.hyper_id) AS hyper_id,
        cpc_price,
        cpa_price
      FROM ma1734_cpc_clicks FULL JOIN ma1734_cpa_clicks
      ON ma1734_cpc_clicks.yandexuid = ma1734_cpa_clicks.yandexuid
        AND ma1734_cpc_clicks.hyper_id = ma1734_cpa_clicks.hyper_id
    ) clicks
    ON ma1734_access.yandexuid = clicks.yandexuid
      AND ma1734_access.hyper_id = clicks.hyper_id
  GROUP BY
    ma1734_access.hyper_id,
    ma1734_access.user_group
) a
GROUP BY hyper_id
HAVING cpm_avg > 0


---- xxxxx

SELECT
  ${hiveconf:start_date} AS start_date,
  ${hiveconf:end_date} AS end_date,

  hyper_id,
  AVG(cpm) AS cpm_avg,
  COUNT(*) AS n,
  STDDEV_SAMP(cpm) AS sd,
  collect_list(cpm) AS cpm_array -- для отладки
FROM
(
  SELECT -- считаем cpm КМ для каждой группы
    access.hyper_id,
    user_group,
    -- sum(n_shows) AS n_shows,
    -- sum(cpc_price) AS cpc_price,
    -- sum(cpa_price) AS cpa_price,
    (sum(cpa_price) + sum(cpc_price)) / sum(n_shows) AS cpm
  FROM
  (
    SELECT -- сколько просмотров конкретных страниц КМ было у определённого пользователя + раздаётся случайная группа
      yandexuid,
      page_groupid_2 as hyper_id,
      -- случайное определение группы
      INT(SUBSTR(yandexuid, 1, 7)) % ${hiveconf:n_groups} AS user_group,
      COUNT(*) AS n_shows
    FROM
    (
      SELECT -- оставляем только КМ и проставляем page_groupid_2
        yandexuid,
        -- термин page_groupid_2 используется в рамках задачи:
        -- https://st.yandex-team.ru/MARKETANSWERS-1587
        CASE
          WHEN regexp_extract(request_path, '^/product.*/\\d+', 0) <> ''
            THEN regexp_extract(request_path, '^/product.*/(\\d+)', 1)
          ELSE 0
        END as page_groupid_2
      FROM 
      (
        SELECT -- выгрузка из front_access с нужными условиями
          yandexuid,
          parse_url(concat('https://market.yandex.ru', request), 'PATH') as request_path
        FROM robot_market_logs.front_access
        WHERE
          day BETWEEN ${hiveconf:start_date} AND ${hiveconf:end_date}
          AND yandexuid IS NOT NULL
          AND status = '200' -- страница загружена без ошибок
          AND nvl(instr(vhost, 'market.yandex.'), 0) <> 0 -- только desktop
          -- в рамках данной задачи не критично, но лучше было бы исключить ещё данные о сотрудниках яндекса
      ) a
      WHERE
        -- это означет, что это КМ (т.е. page_groupid_1 = 1)
        regexp_extract(request_path, '^/product.*/\\d+', 0) <> ''
        -- удалось вытащить id КМ и он не ноль
        AND regexp_extract(request_path, '^/product.*/(\\d+)', 1) > 0
    ) b
    GROUP BY
      yandexuid,
      page_groupid_2
  ) access LEFT JOIN 
  (
    -- cpc клики (надо заджойнить)
    SELECT
      yandexuid,
      hyper_id,
      SUM(price) AS cpc_price -- в рублях!
    FROM
    (
      SELECT
        cookie as yandexuid,
        hyper_id,
        price*30/100 as price -- в рублях
      FROM robot_market_logs.clicks
      WHERE
        day BETWEEN ${hiveconf:start_date} AND ${hiveconf:end_date}
        AND nvl(filter, 0) = 0 -- не накрутка
        AND state = 1 -- убираем клики сотрудников яндекса
        -- выяснить почему такое может быть:
        AND nvl(cookie, '') <> ''
        AND hyper_id > 0
        -- desktop КМ
        AND pp IN (6, 61, 62, 63, 64, 13, 21, 200, 201, 205, 206, 207, 208, 209, 210, 211, 26, 27, 144)
    ) a
    GROUP BY
      yandexuid,
      hyper_id
  ) cpc_clicks
  ON access.yandexuid = cpc_clicks.yandexuid AND
    access.hyper_id = cpc_clicks.hyper_id
  LEFT JOIN
  (
    -- CPA клики
    SELECT
      yandexuid,
      hyper_id,
      sum(price) AS cpa_price
    FROM
    (
      SELECT
        cookie AS yandexuid,              -- кука yandexuid или пустое значение
        hyper_id,
        -- 0.05 оценочное значение, после запуска https://paste.yandex-team.ru/170192
        -- https://st.yandex-team.ru/MARKETANSWERS-1587#1477662737000
        offer_price*fee*0.05 AS price  -- в рублях
      FROM robot_market_logs.cpa_clicks
      WHERE
        day BETWEEN ${hiveconf:start_date} AND ${hiveconf:end_date}
        AND nvl(filter, 0) = 0 -- убираем накрутку
        AND state = 1 -- исклчаем сотрудников яндекса
        AND nvl(type_id, 0) = 0 -- 0 - нормальный cpa-click, 2 - показ карточки offera
        AND nvl(cookie, '') <> ''
        AND hyper_id > 0
        -- desktop КМ
        AND pp IN (6, 61, 62, 63, 64, 13, 21, 200, 201, 205, 206, 207, 208, 209, 210, 211, 26, 27, 144)
    ) a
    GROUP BY
      yandexuid,
      hyper_id
  ) cpa_clicks
  ON access.yandexuid = cpa_clicks.yandexuid AND
    access.hyper_id = cpa_clicks.hyper_id
  GROUP BY
    access.hyper_id,
    user_group
) a
GROUP BY
  hyper_id