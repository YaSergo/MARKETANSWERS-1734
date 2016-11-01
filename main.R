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

offers_data <- read.csv(file = "~/Downloads/query_result (39).csv", na.strings = "NULL")
#cpm_data_ext <- merge(x = cpm_data, y = offers_data, by = "hyper_id", all.x = TRUE)
cpm_data_good_ext <- merge(x = cpm_data_good, y = offers_data, by = "hyper_id", all.x = TRUE)
cpm_data_good_ext <- cpm_data_good_ext[complete.cases(cpm_data_good_ext), ]

corr_func <- function(coef, cpm, cpc, feeincome){
  return(cor(x = cpm, y = cpc * coef + feeincome))
}

coef <- seq(from = 0, to = 75, by = 0.1)
y_all <- sapply(coef, function(x){corr_func(x, cpm = cpm_data_good_ext$avg_cpm,
                                   cpc = cpm_data_good_ext$avg_cbid_all,
                                   feeincome = cpm_data_good_ext$avg_feeincome_all)})
y_15 <- sapply(coef, function(x){corr_func(x, cpm = cpm_data_good_ext$avg_cpm,
                                           cpc = cpm_data_good_ext$avg_cbid_15,
                                           feeincome = cpm_data_good_ext$avg_feeincome_15)})
y_30 <- sapply(coef, function(x){corr_func(x, cpm = cpm_data_good_ext$avg_cpm,
                                           cpc = cpm_data_good_ext$avg_cbid_30,
                                           feeincome = cpm_data_good_ext$avg_feeincome_30)})
y_45 <- sapply(coef, function(x){corr_func(x, cpm = cpm_data_good_ext$avg_cpm,
                                           cpc = cpm_data_good_ext$avg_cbid_45,
                                           feeincome = cpm_data_good_ext$avg_feeincome_45)})


plotdata <- data.frame(coef = coef, y = c(y_all, y_15, y_30, y_45),
                       type = as.factor(c(rep("all", length(y_all)),
                                          rep("15", length(y_15)),
                                          rep("30", length(y_30)),
                                          rep("45", length(y_45)))
                       )
)
p <- ggplot(data = plotdata, aes(x = coef, y = y, col = type))+
  geom_line() +
  ylim(0.6, 0.8) +
  ylab("Корреляция")
print(p)
ggsave(filename="./output/corr.jpg", plot=p)

cpm_data_good_ext$cpm.predict <- cpm_data_good_ext$avg_cbid_se*28 + cpm_data_good_ext$avg_feeincome_fe
ggplot(data = cpm_data_good_ext, aes(x = cpm_data_good_ext$cpm.predict,
                                     y = cpm_data_good_ext$avg_cpm))+
  geom_point(alpha = 0.8)
