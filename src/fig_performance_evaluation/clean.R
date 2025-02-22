doc <- "

This script is used to prepare plot data for performance evaluation

Usage:
  clean.R [options]

Options:
  --input_csv=INPUT_CSV       File to load the csv
  --output_path=OUTPUT_PATH   File to output plot data as rds
  --data_type=DATA_TYPE       Type of data to processed, one of real, sim [default: real]
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

# Custom functions
wrangle_data <- function(df) {
  wrangle_df <- df %>%
    rename(method = method_name) %>%
    # Given there's same result for rgcca and sgcca
    # going to drop those of rgcca and retain sgcca only.
    filter(method != "rgcca") %>%
    group_by(method, dataset) %>%
    summarise(
      across(
        .cols=c(auc, f1_score),
        .fns=list(mean = mean, sd = sd)),
      .groups = "drop"
    ) %>%
    ungroup() %>%
    # Then rank the performance of each method within each dataset
    # I.e. For Dataset L, could be m1, m3 , m5, m2 , m6 from best to worst (left to right)
    group_by(dataset) %>%
    # TODO:  ~~Sort in desceding order, and rank them, i.e. 1st equals top performing~~
    #mutate(ranking = rank(desc(auc_mean))) %>%
    mutate(ranking = rank(auc_mean)) %>%
    ungroup() %>%
    # Rename method names
    mutate(
      method = case_when(
        str_detect(method, "mofa") ~ "mofa + glmnet",
        str_detect(method, "sgcca") ~ "sgcca + lda",
        str_detect(method, "cooperative") ~ "multiview",
        TRUE ~ method
        )
    ) %>%
    select(
      method, dataset, ranking,
      auc_mean, auc_sd, f1_score_mean, f1_score_sd
    ) %>%
    arrange(ranking)
  return(wrangle_df)
}


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

# Function to clean sim data for plot
clean_sim <- function(wr_df) {
  clean_df <- wr_df %>%
    retrieve_sim_params() %>%
    # Then only retain relevant cols
    select(method, dataset, ranking ,
           auc_mean, auc_sd, f1_score_mean, f1_score_sd,
           signal, corr, n, p)

  return(clean_df)
}

# ==================================================
# First load data and clean it for plotting

#input_path <- "data/metrics.csv"



main <- function(input_path, output_path, data_type=c("real", "sim")) {
  data_type <- match.arg(data_type)
  # First do common wrangling on the input data
  wrangle_df <- read.csv(input_path) %>%
    as_tibble() %>%
    wrangle_data()


  # Handle data type-specific processing
  clean_rds <- switch(
    data_type,
    sim = clean_sim(wrangle_df),
    real = clean_real(wrangle_df)
  )

  # Then this to disk as rds
  saveRDS(clean_rds, file = output_path)
  message("\nWritten data to: ", output_path)
}



# Execute the main function here

main(input_path = here(opt$input_csv),
     output_path = here(opt$output_path),
     data_type = opt$data_type)


