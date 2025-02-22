doc <- "

This script is used to make plot data for figure of feature selection for sim data.

Usage:
  clean_sim.R [options]

Options:
  --input_csv=INPUT_CSV       Path to read in the feature selection result
  --output_path=OUTPUT        Path to write out plot data
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(tidyr)

source(here::here("src/common_helpers.R"))
  source(here::here("src/fig_feature_selection/sim_fs_helpers.R"))
source(here::here("src/fig_feature_selection/_feature_selection_utils.R"))

# Function to clean data for plotting simulated data
clean_sim <- function(feat_result_df) {
  # These helpers are in extra file

  # Separate to get all counts
    all_counts_df <- feat_result_df %>%
      group_by(method, dataset, view, feature_type) %>%
      summarize(n = n()) %>%
      ungroup()


    merged_df <- feat_result_df %>%
      group_by(method, dataset, view) %>%
        arrange(desc(abs(coef)), .by_group = TRUE) %>%
      group_map(~ {
        # Find a match in the reference df to see its corresponding counts
        matched <- all_counts_df %>%
          filter(method == .y$method, dataset == .y$dataset, view == .y$view)

        # Get the number of true and noise this depends on the all_counts_df
        top_num <- matched %>% filter(feature_type != "noise") %>% pull(n)
        bottom_num <- matched %>% filter(feature_type == "noise") %>% pull(n)

        # Then pull each
        top_sliced <- slice_head(.x , n = top_num) %>%
          count(feature_type, name = "n_selected") %>%
          mutate(category = "top_counts")
        bottom_sliced <- slice_tail(.x, n = bottom_num) %>%
          count(feature_type, name = "n_selected") %>%
          mutate(category = "bottom_counts")

        binded <- bind_rows(top_sliced, bottom_sliced)
        output <- bind_cols(.y, binded)
        return(output)
      }) %>%
        bind_rows() %>%
        ungroup()

  top_identifier = "top_counts"
  bottom_identifier = "bottom_counts"

  flat_bin_metric_df <- merged_df %>%
    group_by(method, dataset, view) %>%
    summarize(
      TP = sum(n_selected[category == top_identifier & feature_type == "real"], na.rm = TRUE),
      FP = sum(n_selected[category == top_identifier & feature_type == "noise"], na.rm = TRUE),
      FN = sum(n_selected[category == bottom_identifier & feature_type == "real"], na.rm = TRUE),
      TN = sum(n_selected[category == bottom_identifier & feature_type == "noise"], na.rm = TRUE),
      N = sum(TP, TN, FP, FN),
      .groups = "drop"
    )

  flat_bin_metric_df %>%
    group_by(method, dataset, view) %>%
    summarize(sensitivity = TP / (TP + FN),

              # Specificity
              specificity = TN / (TN + FP),

              # Precision
              precision = TP / (TP + FP),

              # Accuracy
              accuracy = (TP + TN) / N) %>%
    retrieve_sim_params()
}

main <- function(input_path, output_path) {

  # First load in data and wrangle it
  feat_result_df <- data.table::fread(input_path) %>%
    as_tibble() %>%
    wrangle_feat_selection()


  # # Handle data type-specific processing
  clean_rds <- clean_sim(feat_result_df)

  saveRDS(clean_rds, file = output_path)
}

# convert weights > ranks > spearman corr >
# heatmap > stratify by sim and real > stratify by tuned params
opt <- docopt::docopt(doc)

# Convenient vars
input_path <- opt$input_csv
output_path <- opt$output_path


# And call the main function
main(input_path = input_path, output_path = output_path)
