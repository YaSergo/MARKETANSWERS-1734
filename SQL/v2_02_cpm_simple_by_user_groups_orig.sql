set start_date='2016-10-10';
set end_date=  '2016-11-10';


-- access
SELECT
  yandexuid,
  page_groupid_2 as hyper_id,
  -- случайное определение группы
  INT(SUBSTR(yandexuid, 1, 7)) % 90 AS user_group,
  COUNT(*) AS n_shows
FROM
(
  SELECT
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
    SELECT
      yandexuid,
      parse_url(concat('https://market.yandex.ru', request), 'PATH') as request_path
    FROM robot_market_logs.front_access
    WHERE
      day = '2016-11-10'
      AND hour = 3
      AND yandexuid IS NOT NULL
      AND status = '200' -- страница загружена без ошибок
      AND nvl(instr(vhost, 'market.yandex.'), 0) <> 0 -- только desktop
      -- в рамках данной задачи не критично, но лучше было бы исключить ещё данные о сотрудниках яндекса
  ) a
  WHERE
    -- это означет, что page_groupid_1 = 1
    regexp_extract(request_path, '^/product.*/\\d+', 0) <> ''
) b
GROUP BY
  yandexuid,
  page_groupid_2

-- cpc клики (надо заджойнить)
SELECT
  yandexuid,
  hyper_id,
  SUM(price) AS price -- в рублях!
FROM
(
  SELECT
    cookie as yandexuid,
    hyper_id,
    price*30/100 as price -- в рублях
  FROM robot_market_logs.clicks
  WHERE
    day = '2016-11-10'
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
SELECT
  yandexuid,
  hyper_id,
  sum(price) AS price
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
    day = '2016-11-10'
    AND nvl(filter, 0) = 0 -- убираем накрутку
    AND state = 1 -- исклчаем сотрудников яндекса
    AND nvl(type_id, 0) = 0 -- ???
    AND nvl(cookie, '') <> ''
    AND hyper_id > 0
    -- desktop КМ
    AND pp IN (6, 61, 62, 63, 64, 13, 21, 200, 201, 205, 206, 207, 208, 209, 210, 211, 26, 27, 144)
) a
GROUP BY
  yandexuid,
  hyper_id







SELECT
  yandexuid,
  hyper_id,
  -- item_revenue считается в фишках, поэтому нет деления на 100
  -- 0.05 оценочное значение, после запуска https://paste.yandex-team.ru/170192
  -- https://st.yandex-team.ru/MARKETANSWERS-1587#1477662737000
  sum(item_revenue)*0.05*30 as price -- в рублях!
FROM
(
  SELECT
    buyer_uid AS yandexuid, -- кука yandexuid или пустое значение
    model_id AS hyper_id,
    item_revenue
  FROM analyst.orders_dict
  WHERE
    creation_day = '2016-11-10'
    AND NOT order_is_fake AND NOT buyer_is_fake AND NOT shop_is_fake -- устраняем фейки из данных
    -- убираем данные без указания пользователя
    AND nvl(buyer_uid, '') <> ''
    AND model_id > 0
    -- desktop КМ
    AND pp IN (6, 61, 62, 63, 64, 13, 21, 200, 201, 205, 206, 207, 208, 209, 210, 211, 26, 27, 144)
) a
GROUP BY
  yandexuid,
  hyper_id