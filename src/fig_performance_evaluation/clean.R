doc <- "

This script is used to prepare plot data for performance evaluation

Usage:
  clean.R [options]

Options:
  --input_csv=INPUT_CSV       File to load the csv
  --output_csv=OUTPUT_CSV      File to output plot data as csv
"

# Parse doc
opt <- docopt::docopt(doc)

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(tibble)
library(here)
library(stringr)
library(tidyr)
suppressPackageStartupMessages(library(ComplexHeatmap))

# Verbose message
message("\nRendering figure of performance evaluation of classification")

# Custom functions
wrangle_data <- function(df) {
  clean_df <- df %>%
    rename(method = method_name) %>%
    # Given there's same result for rgcca and sgcca
    # going to drop those of rgcca and retain sgcca only.
    filter(method != "rgcca") %>%
    # Add identifier to tell which one real or simulated
    group_by(method, dataset) %>%
    summarise(
      across(
        .cols=c(auc, f1_score, accuracy, balanced_accuracy, precision, recall),
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
    mutate(
      is_simulated = case_when(
        str_detect(dataset, "sim") ~ "yes",
        TRUE ~ "no"
      )
    ) %>%
    # Rename method names
    mutate(
      method = case_when(
        str_detect(method, "mofa") ~ "mofa + glmnet",
        str_detect(method, "sgcca") ~ "sgcca + lda",
        TRUE ~ method
      )
    ) %>%
    select(
      method, dataset, ranking,
      auc_mean, auc_sd, f1_score_mean, f1_score_sd, is_simulated
    ) %>%
    arrange(ranking)
  return(clean_df)
}

# ==================================================
# First load data and clean it for plotting

#input_path <- "data/metrics.csv"


main <- function(input_path, output_path) {
  clean_df <- read.csv(input_path) %>%
    as_tibble() %>%
    wrangle_data()

  write.csv(clean_df, file = output_path, row.names = F)
  message("\nWritten data to: ", output_path)
}



# Execute the main function here

main(input_path = here(opt$input_csv), output_path = here(opt$output_csv))


