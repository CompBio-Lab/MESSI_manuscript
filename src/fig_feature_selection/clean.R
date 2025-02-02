doc <- "

This script is used to make plot data for figure of feature selection.

Usage:
  clean.R [options]

Options:
  --input_csv=INPUT_CSV       Path to read in the feature selection result
  --output_csv=OUTPUT_CSV     Path to write out plot data
  --data_type=DATA_TYPE       Type of data to processed. One of real, sim [default: real]

"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)
library(stringr)
library(tidyr)

# Custom function
wrangle_feat_selection <- function(df) {
  df %>%
  # Need to fix error for mogonet appending view in front of feature
  mutate(
    feature = case_when(
      str_detect(method, "mogonet") ~ paste(view, feature, sep="_"),
      TRUE ~ feature
    ),
    # Rename rgcca to sgcca
    method = case_when(
      str_detect(method, "rgcca") ~ "sgcca",
      TRUE ~ method
    )
  ) %>%
    # SGCCA has slight problem in missing a feature in tcga-brca and tcga-kipan???
    # So need to drop this
    filter(! (
      (feature == "RNAseq_HiSeq_Gene_level_GAGE1" & dataset_name == "tcga-brca") |
        (feature == "RNAseq_HiSeq_Gene_level_C8orf71" & dataset_name == "tcga-kipan")
    )
    ) %>%
    mutate(
      is_simulated = case_when(
        str_detect(dataset_name, "sim") ~ "simulated",
        TRUE ~ "real"
      )
    ) %>%
    # Rename the method names
    mutate(
      method = case_when(
        str_detect(method, "sgcca") ~ "sgcca + lda",
        str_detect(method, "mofa") ~ "mofa + glmnet",
        TRUE ~ method
      )
    )
}


#input_path <- "data/all_feature_selection_results.csv"
main <- function(input_path, output_path, data_type) {
  # First load in data and wrangle it
  feat_result_df <- read.csv(input_path) %>%
    as_tibble() %>%
    wrangle_feat_selection()

  # Some intermediate dataframes here for using later
  # Get rankings first
  ranking_df <- feat_result_df %>%
    group_by(method, dataset_name, view) %>%
    # So the coef with rank number smaller means better
    # ie. rank 1 (highest) > rank2 > ... rank 10 > ... rank n
    mutate(ranking = rank(desc(abs(coef)))) %>%
    ungroup() %>%
    select(-coef)

  wide_ranking_df <- ranking_df %>%
    pivot_wider(names_from = method, values_from=ranking) %>%
    rename(dataset = dataset_name)

  # Lastly write it out as csv
  write.csv(wide_ranking_df, file=output_path, row.names=FALSE)
}



# convert weights > ranks > spearman corr >
# heatmap > stratify by sim and real > stratify by tuned params
opt <- docopt::docopt(doc)

# Convenient vars
input_path <- opt$input_csv
output_path <- opt$output_csv
data_type <- opt$data_type

# And call the main function
main(input_path = input_path, output_path = output_path, data_type = data_type)
