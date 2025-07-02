doc <- "

This script is used to prepare plot data for performance evaluation at simulated data.

Usage:
  clean_sim.R [options]

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

#source(here::here("src/common_helpers.R"))
source(here::here("src/common_helpers/retrieve_sim_params.R"))
source(here::here("src/fig_performance_evaluation/_performance_evaluation_utils.R"))
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



main <- function(input_path, output_path) {
  if (length(input_path) == 0) {
    input_path <- "data/raw/simulated_data_results/metrics.csv" |>
      here::here()
  }
  # First do common wrangling on the input data
  wrangle_df <- data.table::fread(input_path) %>%
    as_tibble() %>%
    wrangle_data() %>%
    # TODO: Uggly fix here
    mutate(
     method = case_when(
       str_detect(method, "mofa") ~ "mofa-Factor1 + glmnet",
       TRUE ~ method
       )
    )


  # Handle data type-specific processing
  clean_rds <- clean_sim(wrangle_df)

  # Then this to disk as rds
  saveRDS(clean_rds, file = output_path)
  message("\nWritten data to: ", output_path)
}



# Execute the main function here

main(input_path = here(opt$input_csv),
     output_path = here(opt$output_path)
)


