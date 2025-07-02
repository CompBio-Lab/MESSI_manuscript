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
library(data.table)

#source(here::here("src/common_helpers.R"))
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



main <- function(input_path, output_path) {
  if (is.null(input_path)) {
    input_path <- "data/raw/real_data_results/metrics.csv"
  }
  # Datasets to exclude
  exclude_data <- c("tcga-chol", "tcga-kipan")
  # First do common wrangling on the input data


  wrangle_df <- fread(input_path) %>%
    wrangle_data() %>%
    # TODO: this a fix for real data only
    mutate(method = str_remove(method, "_ncomp-2")) %>%
    # Filter the unwanted data
    filter(!(tolower(dataset) %in% exclude_data)) %>%
    # For performance eval, ncomp could use the latest ncomp as it includes
    # previous ncomp
    filter(!str_detect(tolower(method), "ncomp-1")) %>%
    as_tibble()

  # Handle data type-specific processing
  clean_rds <- clean_real(wrangle_df)

  # Then this to disk as rds
  saveRDS(clean_rds, file = output_path)
  message("\nWritten data to: ", output_path)
}



# Execute the main function here

main(input_path = here(opt$input_csv),
     output_path = here(opt$output_path)
)


