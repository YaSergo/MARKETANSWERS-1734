# загрузка данных
cpm_data <- read.csv("~/Downloads/query_result (35).csv")
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
write.csv(x = cpm_data, file = "output/cpm_data.csv")

# формируем data frame с "хорошими" hyper_id
cpm_data_good <- cpm_data[cpm_data$pvalue < 0.05, ]

write.csv(x = cpm_data_good, file = "output/cpm_data_good.csv")

# Графики плотности вероятности для наиболее частовстречающихся категорий
library(ggplot2)
category_id_good <- aggregate(name ~ category_id, data = cpm_data_good, FUN = length)
category_id_good <-
  category_id_good$category_id[category_id_good$name > quantile(category_id_good$name, 0.85)]
category_id_good <- as.numeric(as.character(category_id_good))

cpm_data_good$category_id <- as.factor(cpm_data_good$category_id)

p <- ggplot(data = cpm_data_good[cpm_data_good$category_id %in% category_id_good, ], aes(x = avg_cpm, fill = category_id))+
  geom_density(alpha = 0.6)
ggsave(filename="./output/density.jpg", plot=p)
