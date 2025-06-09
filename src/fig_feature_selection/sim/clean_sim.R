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
# old_clean_sim <- function(feat_result_df) {
#   # These helpers are in extra file
#
#   # Separate to get all counts
#     all_counts_df <- feat_result_df %>%
#       group_by(method, dataset, view, feature_type) %>%
#       summarize(n = n()) %>%
#       ungroup()
#
#
#     merged_df <- feat_result_df %>%
#       group_by(method, dataset, view) %>%
#         arrange(desc(abs(coef)), .by_group = TRUE) %>%
#       group_map(~ {
#         # Find a match in the reference df to see its corresponding counts
#         matched <- all_counts_df %>%
#           filter(method == .y$method, dataset == .y$dataset, view == .y$view)
#
#         # Get the number of true and noise this depends on the all_counts_df
#         top_num <- matched %>% filter(feature_type != "noise") %>% pull(n)
#         bottom_num <- matched %>% filter(feature_type == "noise") %>% pull(n)
#
#         # Then pull each
#         top_sliced <- slice_head(.x , n = top_num) %>%
#           count(feature_type, name = "n_selected") %>%
#           mutate(category = "top_counts")
#         bottom_sliced <- slice_tail(.x, n = bottom_num) %>%
#           count(feature_type, name = "n_selected") %>%
#           mutate(category = "bottom_counts")
#
#         binded <- bind_rows(top_sliced, bottom_sliced)
#         output <- bind_cols(.y, binded)
#         return(output)
#       }) %>%
#         bind_rows() %>%
#         ungroup()
#
#   top_identifier = "top_counts"
#   bottom_identifier = "bottom_counts"
#
#   flat_bin_metric_df <- merged_df %>%
#     group_by(method, dataset, view) %>%
#     summarize(
#       TP = sum(n_selected[category == top_identifier & feature_type == "real"], na.rm = TRUE),
#       FP = sum(n_selected[category == top_identifier & feature_type == "noise"], na.rm = TRUE),
#       FN = sum(n_selected[category == bottom_identifier & feature_type == "real"], na.rm = TRUE),
#       TN = sum(n_selected[category == bottom_identifier & feature_type == "noise"], na.rm = TRUE),
#       N = sum(TP, TN, FP, FN),
#       .groups = "drop"
#     )
#
#   flat_bin_metric_df %>%
#     group_by(method, dataset, view) %>%
#     summarize(sensitivity = TP / (TP + FN),
#
#               # Specificity
#               specificity = TN / (TN + FP),
#
#               # Precision
#               precision = TP / (TP + FP),
#
#               # Accuracy
#               accuracy = (TP + TN) / N) %>%
#     retrieve_sim_params()
# }

clean_sim <- function(feat_result_df) {
  all_counts_df <- feat_result_df %>%
    count(method, dataset, view, feature_type, name = "n") %>%
    pivot_wider(names_from = feature_type, values_from = n, values_fill = 0) %>%
    rename(n_real = real, n_noise = noise)

  # Step 2: Join this to feat_result_df
  feat_with_counts <- feat_result_df %>%
    left_join(all_counts_df, by = c("method", "dataset", "view")) %>%
    arrange(method, dataset, view, desc(abs(coef))) %>%
    group_by(method, dataset, view) %>%
    mutate(rank = row_number()) %>%
    mutate(category = case_when(
      rank <= first(n_real) ~ "top_counts",
      rank > n() - first(n_noise) ~ "bottom_counts",
      TRUE ~ NA_character_
    )) %>%
    ungroup() %>%
    filter(!is.na(category)) %>%
    count(method, dataset, view, feature_type, category, name = "n_selected")

  # Step 3: Compute confusion matrix components
  flat_bin_metric_df <- feat_with_counts %>%
    pivot_wider(
      names_from = c(category, feature_type),
      values_from = n_selected,
      values_fill = 0
    ) %>%
    transmute(
      method, dataset, view,
      TP = top_counts_real,
      FP = top_counts_noise,
      FN = bottom_counts_real,
      TN = bottom_counts_noise,
      N = TP + FP + FN + TN
    )

  # Step 4: Calculate metrics and return it
  flat_bin_metric_df %>%
    group_by(method, dataset, view) %>%
    summarize(
      sensitivity = TP / (TP + FN),
      specificity = TN / (TN + FP),
      precision = TP / (TP + FP),
      accuracy = (TP + TN) / N
    ) %>%
    retrieve_sim_params()
}

main <- function(input_path, output_path) {
  # First load in data and wrangle it
  feat_result_df <- data.table::fread(input_path) %>%
    as_tibble() %>%
    wrangle_feat_selection() %>%
    # And additionally remove those extra info in view
    # Need additional standardizing of views
    mutate(view = case_when(
      str_detect(view, "-Factor") ~ str_remove(view, "-Factor.*"),
      str_detect(view, "-ncomp") ~ str_remove(view, "-ncomp.*"),
      TRUE ~ view
    ))


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
