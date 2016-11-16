SELECT -- считаем количество yandexuid в каждой группе
  user_group,
  COUNT(*) AS num_yandexuids
FROM
(
  SELECT -- устанавливаем соответствие yandexuid - группа
    yandexuid,
    -- https://wiki.yandex-team.ru/Cookies/yandexuid/#format
    INT(SUBSTR(yandexuid, 1, 7)) % 90 AS user_group
  FROM
  (
    SELECT -- определяем перечень уникальных yandexuid за период времени
      DISTINCT yandexuid 
    FROM robot_market_logs.front_access
    WHERE
      day = '2016-11-10'
      AND hour = 3
      AND yandexuid IS NOT NULL
      -- страница загружена без ошибок
      AND status = '200'
  ) a
) b
GROUP BY user_group
