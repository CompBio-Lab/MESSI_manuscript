doc <- "

This script is used to prepare plot data for performance evaluation

Usage:
  clean.R [options]

Options:
  --input_csv=INPUT_CSV       File to load the csv
  --output_csv=OUTPUT_CSV     File to output plot data as csv
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


retrieve_sim_params <- function(df) {
  df %>%
    # First handle the strategy, then handle params separately based on strategy
    mutate(
      # Extract the strategy part
      strategy = str_extract(dataset, "strategy-[^_]+") %>%
        str_remove("strategy-"),
      # Extract the rest of the parameters
      params = str_extract(dataset, "strategy-[^_]+_(.*)$") %>%
        str_remove("^strategy-[^_]+_")
    )  %>%
    mutate(
      n = str_extract(params, "n-\\d+"),
      p = str_extract(params, "p-\\d+"),
      dt = str_extract(params, "dt-\\d+"),
      rho = str_extract(params, "rho-[\\d\\.]+"),
      rep = str_extract(params, "rep-\\d+")
    ) %>%
    mutate(across(n:rep, ~ str_remove(., "^[a-z]+-") %>% as.numeric())) %>%
    select(-c(params))
}


main <- function(input_path, output_path, data_type=c("real", "sim")) {
  data_type <- match.arg(data_type)
  wrangled_df <- read.csv(input_path) %>%
    as_tibble() %>%
    wrangle_data()


  # Handle data type-specific processing
  clean_df <- switch(
    data_type,
    sim = wrangled_df %>% select(-is_simulated) %>% retrieve_sim_params(),
    real = wrangled_df # No additional processing for real data
  )


  write.csv(clean_df, file = output_path, row.names = F)
  message("\nWritten data to: ", output_path)
}



# Execute the main function here

main(input_path = here(opt$input_csv),
     output_path = here(opt$output_csv),
     data_type = opt$data_type)


