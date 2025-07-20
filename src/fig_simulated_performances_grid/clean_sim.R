doc <- "

This script is used to prepare plot data for plotting grid of simulated data performances like AUC,
Sensitivity and Specicificity

Usage:
  clean_sim.R [options]

Options:
  --perf_input_path=PERF_PATH         AUC performance plot data rds
  --feat_input_path=FEAT_PATH         Feature Selection Performance plot data rds
  --output_path=OUTPUT_PATH           File to output plot data as csv
"

# Load library
suppressPackageStartupMessages(library(dplyr))


main <- function(perf_input_path, feat_input_path, output_path) {
  if (is.null(perf_input_path)) {
    perf_input_path <- "data/processed/fig_performance_evaluation_sim_plot_data.rds" |>
      here::here()
  }

  if (is.null(feat_input_path)) {
    feat_input_path <- "data/processed/fig_feature_selection_sim_plot_data.rds" |>
      here::here()
  }

  if (is.null(output_path)) {
    output_path <- "data/processed/simulation_performance_grid_df.csv" |>
      here::here()
  }

  # Load the data first
  feat_input_data <- readRDS(feat_input_path)
  perf_input_data <- readRDS(perf_input_path)

  # Apply some wrangling / summarizing
  plot_data_feat <- feat_input_data %>%
    ungroup() %>%
    # Keep the relevant levels only
    filter(signal %in% c(0, 3, 100)) %>%
    group_by(method, dataset, signal, corr) %>%
    summarize(sensitivity = mean(sensitivity),
              specificity = mean(specificity),
              .groups = "drop") %>%
    select(method:specificity, signal, corr)

  plot_data_perf <- perf_input_data %>%
    filter(signal %in% c(0,3,100)) %>%
    select(method, dataset, auc, signal,corr)

  # ==============================================================================
  # Then join both and transform data for plotting
  plot_data_df <- inner_join(
    plot_data_feat, plot_data_perf, by = c("method", "dataset", "signal", "corr")
  ) %>%
  tidyr::pivot_longer(sensitivity:auc, names_to = "metric")

  data.table::fwrite(plot_data_df, file =  here::here(output_path), row.names = F)
  message("\nSaved plot data simulation performance grid into ", output_path)
}

# Parse cli
opt <- docopt::docopt(doc)
# And execute main
main(perf_input_path=opt$perf_input_path, feat_input_path=opt$feat_input_path, output_path=opt$output_path)






