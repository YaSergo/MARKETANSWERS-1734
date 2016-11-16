-- файлик для временного хранения тестируемого sql запроса

SELECT
  yandexuid,
  page_groupid_2,
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
  ) a
  WHERE
    -- это означет, что page_groupid_1 = 1
    regexp_extract(request_path, '^/product.*/\\d+', 0) <> ''
) b
GROUP BY
  yandexuid,
  page_groupid_2
  

SELECT
  yandexuid, -- кука yandexuid или пустое значение
  hyper_id,
  SUM(price) AS price
FROM
(
  SELECT
    cookie as yandexuid, -- кука yandexuid или пустое значение
    hyper_id,
    price -- Цена клика (в фишка-центах).
  FROM robot_market_logs.clicks
  WHERE
    filter = 0 -- не накрутка
    AND state = 1 -- убираем клики сотрудников яндекса
    AND day = '2016-11-10'
    -- выяснить почему такое может быть:
    AND cookie IS NOT NULL
    AND cookie <> ''
    AND hyper_id <> -1
    -- desktop КМ
    AND pp IN (6, 61, 62, 63, 64, 13, 21, 200, 201, 205, 206, 207, 208, 209, 210, 211, 26, 27, 144)
) a
GROUP BY
  yandexuid,
  hyper_id