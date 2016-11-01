SELECT
  hyper_id, name, category_id,
  avg(cpm) as avg_cpm,
  stddev_samp(cpm) as sd,
  count(*) as n,
  collect_list(cpm) AS cpm_array
FROM
(
  SELECT
    main_data.*,
    details.name, details.category_id
  FROM medintsev.market_page_cpm_simple as main_data
  LEFT JOIN dictionaries.models AS details
  ON main_data.hyper_id = details.id
) a
GROUP BY hyper_id, name, category_id
HAVING
  avg_cpm > 0 AND
  n = 21 -- берём только hyper_id, которые были представлены 21 день
  -- если это условие не использоть, то среднее значение и среднеквадратичное
  -- отклонение будут рассчитаны не верно. Ряд тогда будет таким:
  -- 6, 2, 3 вместо 0, 0, ..., 0, 0, 6, 2, 3
