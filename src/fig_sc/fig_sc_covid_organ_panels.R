# ==============================================================================
# fig_sc_covid_organ_panels.R
# Generate all panel plots for the COVID organ dataset.
# ==============================================================================
library(ggplot2)
library(here)


source(here::here("src/fig_sc/sc_figure_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))


plot_fig_sc_covid_organ_panels_main <- function(input_rds_path=NULL, output_dir=NULL,
                                                     text_size=48) {
  if (is.null(input_rds_path)) {
    input_rds_path <- "data/processed/sc/sc_covid_organ_plot_data_list.rds"
  }
  if (is.null(output_dir)) {
    output_dir <- "results/sc"
  }
  # Load the plot data
  plot_data_list <- readRDS(input_rds_path)
  # Now extract each plot data
  panel_D1_data <- plot_data_list$panel_c1_auc_plot_data
  panel_D2_data <- plot_data_list$panel_c2_sig_pathways_count_plot_data
  panel_D3_data <- plot_data_list$panel_c3_pathway_identified_plot_data
  panel_D4_data <- plot_data_list$panel_c4_time_space_plot_data
  # ==============================================================================
  # Now make each plot
  p_D1 <- plot_sc_auc_bar(panel_D1_data, title = "sc-COVID organ",
                          text_size = text_size)
  p_D2 <- plot_sc_sig_pathways_bar(panel_D2_data, facet_var = "organ",
                                   reorder_within = TRUE,
                                   text_size = text_size)
  # ComplexHeatmap plot, there isnt a very good way to fix label size dynamically
  p_D3 <- build_sc_pathway_heatmap(
    panel_D3_data, type_label = "direct_sarscov2",
    col_wrap = 24,
    heatmap_col    = c("0" = "blue", "1" = "red"),
    heatmap_name   = "Pathway\nIdentified",
    heatmap_legend_extra = list(at = c(0, 1), labels = c("No", "Yes"))
  ) |>
    cowplot::ggdraw()
  p_D4 <- plot_sc_time_space(panel_D4_data, text_size = text_size)
  # Unfortunately using harcode paths here
  # For each of these plots save to file
  save_plot_both(p_D1, here(output_dir, "fig_sc_d1_covid_organ_auc_performance_bar_plot.png"))
  save_plot_both(p_D2, here(output_dir, "fig_sc_d2_covid_organ_sig_pathways_count_plot.png"))
  save_plot_both(p_D3, here(output_dir, "fig_sc_d3_covid_organ_pathway_identified_plot.png"))
  save_plot_both(p_D4, here(output_dir, "fig_sc_d4_covid_organ_time_space_plot.png"))
  # ===============
  message("\n[plot_fig_sc_covid_organ_panels_main] Done plotting fig sc covid organ panel")
}

plot_fig_sc_covid_organ_panels_main(
  input_rds_path="data/processed/sc/sc_covid_organ_plot_data_list.rds",
  output_dir="results/sc",
  text_size=12
)
