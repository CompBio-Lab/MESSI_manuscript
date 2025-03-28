doc <- "

This script is used to make plot data for figure of feature selection for real data.

Usage:
  clean_real.R [options]

Options:
  --input_csv=INPUT_CSV       Path to read in the feature selection result
  --output_path=OUTPUT        Path to write out plot data
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(tidyr)

source(here::here("src/common_helpers.R"))
source(here::here("src/fig_feature_selection/_feature_selection_utils.R"))

# Function to clean data for plotting real data
clean_real <- function(df, cor_method="spearman") {
  # Some intermediate dataframes here for using later
  # Get rankings first
  ranking_df <- df %>%
    group_by(method, dataset, view) %>%
    # So the coef with rank number smaller means better
    # ie. rank 1 (highest) > rank2 > ... rank 10 > ... rank n
    mutate(ranking = rank(desc(abs(coef)))) %>%
    ungroup() %>%
    select(-coef)
  # And pivot it to get correlation matri
  cor_mat <- ranking_df %>%
    pivot_wider(names_from = method, values_from=ranking) %>%
    filter(dataset_type == "real") %>%
    select_if(is.numeric) %>%
    select(order(colnames(.))) %>%
    as.matrix() %>%
    cor(method = cor_method)
  # And specifically let the colnames to be dataset
  # TODO: this is not entirely working on the dataset
  # Only works if number of dataset = number of method
  #colnames(cor_mat) <- ranking_df$dataset |> unique() |> sort()

  return(cor_mat)

}


main <- function(input_path, output_path) {

  # First load in data and wrangle it
  feat_result_df <- data.table::fread(input_path) %>%
    as_tibble() %>%
    wrangle_feat_selection()


  # # Handle data type-specific processing
  clean_rds <- clean_real(feat_result_df)

  saveRDS(clean_rds, file = output_path)
}

opt <- docopt::docopt(doc)

# Convenient vars
input_path <- opt$input_csv
output_path <- opt$output_path

# And call the main function
main(input_path = input_path, output_path = output_path)
