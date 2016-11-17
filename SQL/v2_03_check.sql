-- проверить, что нет кликов, которые не подвязываются к access


set start_date='2016-11-15';
set end_date=  '2016-11-15';
set n_groups=   100;

-- access лог
WITH access AS (
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
      regexp_extract(request_path, '^/product.*/(\\d+)', 1) AS page_groupid_2
    FROM 
    (
      SELECT -- выгрузка из front_access с нужными условиями
        yandexuid,
        parse_url(concat('https://market.yandex.ru', request), 'PATH') AS request_path
      FROM robot_market_logs.front_access
      WHERE
        day BETWEEN ${hiveconf:start_date} AND ${hiveconf:end_date}
        AND nvl(yandexuid, '') <> ''
        AND cast(yandexuid as double) IS NOT NULL -- yandexuid бывает каким-то мусором, убираем такие записи
        AND status = '200' -- страница загружена без ошибок
        AND nvl(instr(vhost, 'market.yandex.'), 0) = 1 -- только desktop
        -- в рамках данной задачи не критично, но лучше было бы исключить ещё данные о сотрудниках яндекса
    ) a
    WHERE
      -- удалось вытащить id КМ и он не ноль
      regexp_extract(request_path, '^/product.*/(\\d+)', 1) > 0
  ) b
  GROUP BY
    yandexuid,
    page_groupid_2

-- CPC клики
), cpc_clicks AS (
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

-- CPA клики
), cpa_clicks AS (
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
)


SELECT
  *
FROM
  access FULL JOIN
  (
    SELECT
      nvl(cpc_clicks.yandexuid, cpa_clicks.yandexuid) AS yandexuid,
      nvl(cpc_clicks.hyper_id, cpa_clicks.hyper_id) AS hyper_id,
      cpc_price,
      cpa_price
    FROM cpc_clicks FULL JOIN cpa_clicks
    ON cpc_clicks.yandexuid = cpa_clicks.yandexuid
      AND cpc_clicks.hyper_id = cpa_clicks.hyper_id
  ) clicks
  ON access.yandexuid = clicks.yandexuid
    AND access.hyper_id = clicks.hyper_id
WHERE
  access.yandexuid IS NULL