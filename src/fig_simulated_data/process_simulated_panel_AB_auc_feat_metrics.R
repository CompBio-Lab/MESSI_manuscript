# ============================================================
message("Starting processing data for figure of simulated data panel AB")

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(tibble)
library(here)
library(stringr)
library(tidyr)
library(ggplot2)
library(cowplot)

# Load helper functions
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/retrieve_sim_params.R"))
source(here::here("src/common_helpers/performance_evaluation_utils.R"))
source(here::here("src/common_helpers/standardize_data_funs.R"))
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/fig_simulated_data/_simulated_data_utils.R"))

# ==================================================
# Custom functions to process the performance metrics
# and feature selection results of simulated data

process_sim_auc_df <- function(metric_input_path=NULL) {

  if (is.null(metric_input_path)) {
    metric_input_path <- "data/raw/simulated_data/metrics.csv"
  }

  message("--------------------------------------------------")
  message("Processing performance metrics...")
  message("Reading file: ", metric_input_path)

  sim_perf_df <- data.table::fread(metric_input_path) %>%
    wrangle_sim_data() %>%
    # TODO: uggly fix here
    mutate(
      method = case_when(
        str_detect(tolower(method), "mofa") ~ "mofa-Factor1",
        TRUE ~ method
      )
    ) %>%
    retrieve_sim_params() %>%
    # Filter signals of low med high
    filter(signal %in% c(0,3,100)) %>%
    dplyr::select(method, dataset, auc, signal, corr) %>%
    # Standardize method names purposedly at feature level (remain suffix)
    mutate(method = standardize_method_names(method, "feature"))

  message("Finished processing performance metrics.")
  return(sim_perf_df)
}



process_sim_feat_sensitivity_specificity_df <- function(feat_input_path=NULL) {

  if (is.null(feat_input_path)) {
    feat_input_path <- "data/raw/simulated_data/all_feature_selection_results.csv"
  }

  message("--------------------------------------------------")
  message("Processing feature selection metrics...")
  message("Reading file: ", feat_input_path)

  sim_feat_df <- data.table::fread(feat_input_path) %>%
    wrangle_sim_feat_selection() %>%
    mutate(
      view = case_when(
        str_detect(view, "-Factor") ~ str_remove(view, "-Factor.*"),
        str_detect(view, "-ncomp") ~ str_remove(view, "-ncomp.*"),
        TRUE ~ view
      )
    ) %>%
    clean_feat_sim() %>%
    ungroup() %>%
    # Filtering of low med high signals
    filter(signal %in% c(0, 3, 100)) %>%
    group_by(method, dataset, signal, corr) %>%
    summarize(
      sensitivity = mean(sensitivity),
      specificity = mean(specificity),
      .groups = "drop"
    ) %>%
    dplyr::select(method:specificity, signal, corr) %>%
  mutate(method = standardize_method_names(method, "feature"))

  message("Finished processing feature metrics.")
  return(sim_feat_df)
}



merge_sim_plot_data_panel_AB <- function(perf_df, feat_df, output_path=NULL) {
  if (is.null(output_path)) {
    message("\nWriting to default file: ")
    output_path <- "data/processed/simulated/simulated_panel_AB_plot_data.rds"
  }
  message("--------------------------------------------------")
  message("Merging both peformance metrics and feature selection metrics.. ")
  # Now join them and make it long format
  plot_data_df <- inner_join(
    perf_df, feat_df, by = c("method", "dataset", "signal", "corr")
  ) %>%
    # Reorder it
    dplyr::select(method, dataset, signal, corr, auc, sensitivity, specificity) %>%
    # And turn it to longer
    tidyr::pivot_longer(auc:specificity, names_to = "metric")

  # Correct order should be: mofa-F1, mogonet- multiview?
  method_order <- plot_data_df |>
    filter(signal == "3", metric == "sensitivity") |>
    group_by(method) |>
    summarize(mean_value = mean(value, na.rm = TRUE)) |>
    arrange(mean_value) |>
    dplyr::pull(method)

  # And make many important variables as factor
  final_plot_data <- plot_data_df |>
    dplyr::mutate(
      metric = as.factor(metric),
      signal = factor(signal, labels = c("Signal: None", "Signal: Low ", "Signal: High")),
      corr = as.factor(corr),
      method = factor(method, levels=method_order)
    ) %>% as_tibble()
  message("Plot data for simulated data figure panel AB ready.")
  # Save it for later usage
  message("Saving it as rds to keep factor information, into: ", output_path)
  saveRDS(final_plot_data, file=output_path)
  return(final_plot_data)
}

process_sim_panel_AB_main <- function(metric_input_path=NULL, feat_input_path=NULL,
                                      output_path=NULL) {
  # 1. First process metric data
  sim_perf_df <- process_sim_auc_df(
    metric_input_path
  )
  # 2. Then process the feature data
  sim_feat_df <- process_sim_feat_sensitivity_specificity_df(
    feat_input_path
  )
  # 3. Now merge them together and save it
  merged_df <- merge_sim_plot_data_panel_AB(sim_perf_df, sim_feat_df, output_path)
  return(merged_df)
}


# ==============================================================================
# Lastly call this main fun
process_sim_panel_AB_main(
  metric_input_path=here::here("data/raw/simulated_data/metrics.csv"),
  feat_input_path=here::here("data/raw/simulated_data/all_feature_selection_results.csv")
)




