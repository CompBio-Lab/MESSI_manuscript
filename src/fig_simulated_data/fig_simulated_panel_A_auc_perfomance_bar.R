# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(tibble)
library(here)
library(stringr)
library(tidyr)
library(ggplot2)
library(cowplot)

# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/standardize_data_funs.R"))
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/fig_simulated_data/_simulated_data_utils.R"))



plot_simulated_panel_A_auc_bar <- function(input_path=NULL,
                                           output_png_path=NULL,
                                           text_size=9.5) {
  if (is.null(input_path)) {
    input_path <- "data/processed/simulated/simulated_panel_AB_plot_data.rds"
  }

  if (is.null(output_png_path)) {
    output_png_path <- "results/simulated/fig_simulated_panel_A_auc_bar.png"
  }
  # Load the plot data for fig simulated panel AB, auc panel and
  # sensitivity  + specicificy panel
  simulated_panel_AB_plot_data <- readRDS(input_path)

  # First create the independent panels
  auc_panel <- create_panel_plot(
    data = simulated_panel_AB_plot_data,
    metric_filter = "auc",
    metric_label = "AUC",
    y_label_expr = "AUC",
    text_size = text_size + 4
  ) +
    coord_flip()

  # Lastly saving this
  save_plot_both(auc_panel, output_png_path)
  return(auc_panel)
}

plot_simulated_panel_A_auc_bar(
  input_path="data/processed/simulated/simulated_panel_AB_plot_data.rds",
  output_png_path="results/simulated/fig_simulated_panel_A_auc_bar.png",
  text_size=12
  )


