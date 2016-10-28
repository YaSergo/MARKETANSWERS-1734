# загрузка данных
cpm_data <- read.csv("~/Downloads/query_result (33).csv")
cpm_data <- cpm_data[cpm_data$avg_cpm > 0, ]

# функция для расчёта p-value
pvalue_tdist <- function(m, s, n, threshold = 10){
  # m - mean
  # s - sd
  # n - n
  xbar <- m * (1 + threshold / 100)
  t <- (xbar - m) / (s / sqrt(n))
  result <- 2*pt(-abs(t), df=n-1)
  return(result)
}

# считаем p-value
cpm_data$pvalue <- pvalue_tdist(m = cpm_data$avg_cpm, s = cpm_data$sd, n = cpm_data$n)

# формируем data frame с "хорошими" hyper_id
cpm_data_good <- cpm_data[cpm_data$pvalue < 0.05, ]

write.csv(x = cpm_data_good, file = "output/good_hyper_id.csv")
