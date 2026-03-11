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



plot_simulated_panel_B_feat_sensitivity_specificity_bars <- function(input_path=NULL,
                                           output_png_path=NULL,
                                           text_size=9.5) {
  if (is.null(input_path)) {
    input_path <- "data/processed/simulated/simulated_panel_AB_plot_data.rds"
  }

  if (is.null(output_png_path)) {
    output_png_path <- "results/simulated/fig_simulated_panel_B_feat_sensitivity_specificity_bars.png"
  }
  # Load the plot data as df for fig simulated panel B,
  # sensitivity  + specicificy panel, because it is long data ,so filter NON auc
  simulated_panel_AB_plot_data <- readRDS(input_path) %>% filter(metric != "auc")


  sensitivity_panel <- create_panel_plot(
    data = simulated_panel_AB_plot_data,
    metric_filter = "sensitivity",
    metric_label = "True Variables",
    #y_label_expr = expression("Proportion of TP^* / TP^* + FN^*")
    #y_label_expr = expression("Proportion of " * TP^"*" / (TP^"*" + FN^"*"))
    y_label_expr = "Proportion of variables selected",
    text_size = text_size + 3
  ) +
    coord_flip()

  specificity_panel <- create_panel_plot(
    data = simulated_panel_AB_plot_data,
    metric_filter = "specificity",
    metric_label = "Noise Variables",
    #y_label_expr = "Proportion of TN^* / TN^* + FP^*"
    #y_label_expr = expression("Proportion of " * TN^"*" / (TN^"*" + FP^"*"))
    y_label_expr = "Proportion of variables selected",
    text_size = text_size + 3
  ) +
    coord_flip()
  # ==========================================================
  # Merging the panels together
  # Join them now with patchwork
  # Using cowplot is extremely hard due to alignment problems
  library(patchwork)
  feat_plots <- (sensitivity_panel + theme_empty_legend_ticks() + xlab(NULL)) /
    (specificity_panel +
       xlab(NULL))+
    plot_layout(axes = "collect")


  # Lastly saving this
  save_plot_both(feat_plots, output_png_path)
  return(feat_plots)
}

plot_simulated_panel_B_feat_sensitivity_specificity_bars(
  input_path="data/processed/simulated/simulated_panel_AB_plot_data.rds",
  output_png_path="results/simulated/fig_simulated_panel_B_feat_sensitivity_specificity_bars.png",
  text_size=12
)



