# 20161117: решили посмотреть при каких параметрах (кол-во дней, кол-во групп) достигается
# наилучший результат

# номера выгрузок из hive
num_results <- 72:89

# перечень моделей, у которых мы хотим выгрузить результаты и посмотреть их
# 14209841 - Apple iPhone 6S 32Gb
# 13739833 - DJI Phantom 4
models_for_check <- 13739833


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

results <- list()

for (id_result in num_results){
  print(id_result)
  
  file_path <- paste0("~/Downloads/query_result (", id_result, ").csv")
  cpm_data <- read.csv(file_path)
  
  # считаем p-value
  cpm_data$pvalue <- pvalue_tdist(m = cpm_data$cpm_avg, s = cpm_data$sd, n = cpm_data$n)
  #write.csv(x = cpm_data, file = "output/cpm_data.csv")
  
  num_good_models <- sum(cpm_data$pvalue < 0.05)
  cpm_avg <- cpm_data$cpm_avg[cpm_data$hyper_id == models_for_check]
  pvalue  <- cpm_data$pvalue[cpm_data$hyper_id == models_for_check]
  
  results[[length(results) + 1]] <- list(id_result = id_result,
                                         hyper_id = models_for_check,
                                         num_good_models = num_good_models,
                                         cpm_avg = cpm_avg,
                                         pvalue = pvalue)
}

df <- data.frame(matrix(unlist(results), nrow=length(num_results), byrow=T),stringsAsFactors=FALSE)
colnames(df) <- c("id_result", "hyper_id", "num_good_models", "cpm_avg", "pvalue")

df.pvalue <- matrix(round(df$pvalue,4), nrow=6)
df.cpm_avg <- matrix(round(df$cpm_avg,2), nrow=6)

write.csv(x = df.pvalue, file = "./output/choose_best_params/df.pvalue.csv")
write.csv(x = df.cpm_avg, file = "./output/choose_best_params/df.cpm_avg.csv")
