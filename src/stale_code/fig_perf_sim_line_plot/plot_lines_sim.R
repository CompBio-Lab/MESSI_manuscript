doc <- "

This script is used to prepare plot data for performance evaluation at real data

Usage:
  clean_real.R [options]

Options:
  --input_csv=INPUT_CSV       File to load the csv
  --output_path=OUTPUT_PATH   File to output plot data as rds
"

# Parse doc
opt <- docopt::docopt(doc)

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(tibble)
library(here)
library(stringr)
library(tidyr)


source(here::here("src/common_helpers.R"))
source(here::here("src/fig_performance_evaluation/_performance_evaluation_utils.R"))


# Function to clean real data for plot
clean_real <- function(wr_df) {
  auc_matrix <- wr_df %>%
    select(method, dataset, auc_mean) %>%
    pivot_wider(names_from = dataset, values_from = auc_mean) %>%
    arrange(method) %>%
    select(order(colnames(.))) %>%
    tibble::column_to_rownames(var="method") %>%
    as.matrix()

  rank_matrix <- wr_df %>%
    select(method, dataset, ranking) %>%
    pivot_wider(names_from = dataset, values_from = ranking) %>%
    arrange(method) %>%
    select(order(colnames(.))) %>%
    tibble::column_to_rownames(var="method") %>%
    as.matrix()

  return(list(auc_matrix=auc_matrix, rank_matrix=rank_matrix))
}

# ==================================================
# First load data and clean it for plotting

#input_path <- "data/metrics.csv"

input_path <- "data/raw/real_data_results/metrics.csv"

raw_df <- read.csv(input_path) %>%
  as_tibble()

wrangle_df <- read.csv(input_path) %>%
    as_tibble() %>%
    wrangle_data()

  raw_df %>%
    colnames()



new_df <- raw_df %>%
  rename(method = method_name) %>%
  group_by(method, dataset) %>%
  summarize(acc = mean(accuracy),
            bacc = mean(balanced_accuracy),
            f1_score = mean(f1_score),
            auc = mean(auc)) %>%
  ungroup()

# Fix x = dataset, color = method, different y axis
plot_metric_lines <- function(df, y_col, y_label = y_col) {
  if(!all(c("dataset", "method", y_col) %in% colnames(df))) {
    stop(paste0("Specified columns are not in data: 'method', 'dataset '", y_col))
  }
  df %>%
    ggplot(aes(x = dataset, color = method, group = method, y = !!ensym(y_col))) +
    geom_point() +
    geom_line() +
    labs(x = "Dataset", y = y_label, color = "Method") +
    theme_bw()
}

# TODO:
# - reorder x-axis by performance
# - add error bars

# Accuracy plot
plot_metric_lines(new_df, "acc", y_label = "Accuracy")

# Balanced accuracy plot
plot_metric_lines(new_df, "bacc", y_label = "Balanced Accuracy")

# F1 score plot
plot_metric_lines(new_df, "f1_score", y_label = "F1 Score")

new_df$
