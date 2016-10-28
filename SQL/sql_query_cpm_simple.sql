SELECT hyper_id, avg(cpm) as avg_cpm, stddev_samp(cpm) as sd, count(*) as n
FROM
(
  SELECT main_data.* -- оставляем в данных только те hyper_id, которые были представлены все 21 дня
  FROM market_page_cpm_simple as main_data RIGHT JOIN
  (
    SELECT hyper_id
    FROM
    (
      SELECT hyper_id, count(*) as num
      FROM market_page_cpm_simple
      GROUP BY hyper_id
    ) t
    WHERE num = 21
  ) good_hyper_id
  ON main_data.hyper_id = good_hyper_id.hyper_id
) a
GROUP BY hyper_id
HAVING avg_cpm > 0