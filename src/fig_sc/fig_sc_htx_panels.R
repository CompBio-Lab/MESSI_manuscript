# ==============================================================================
# fig_sc_htx_panels.R
# Generate all panel plots for the HTX dataset.
# ==============================================================================
library(ggplot2)
library(here)


source(here::here("src/fig_sc/sc_figure_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))


plot_fig_sc_htx_panels_main <- function(input_rds_path=NULL, output_dir=NULL,
                                                     text_size=48) {
  if (is.null(input_rds_path)) {
    input_rds_path <- "data/processed/sc/sc_htx_plot_data_list.rds"
  }
  if (is.null(output_dir)) {
    output_dir <- "results/sc"
  }
  # Load the plot data
  plot_data_list <- readRDS(input_rds_path)
  # Now extract each plot data
  panel_B1_data <- plot_data_list$panel_c1_auc_plot_data
  panel_B2_data <- plot_data_list$panel_c2_sig_pathways_count_plot_data
  panel_B3_data <- plot_data_list$panel_c3_pathway_identified_plot_data
  panel_B4_data <- plot_data_list$panel_c4_time_space_plot_data
  # ==============================================================================
  # Now make each plot
  p_B1 <- plot_sc_auc_bar(panel_B1_data, title = "sc-HTX",
                          text_size = text_size)
  # This data_label is just HTX labelling from the process script
  p_B2 <- plot_sc_sig_pathways_bar(panel_B2_data, facet_var = "data_label",
                                   text_size = text_size)
  # ComplexHeatmap plot, there isnt a very good way to fix label size dynamically
  p_B3 <- build_sc_pathway_heatmap(
    panel_B3_data,
    type_label     = "allograft_rejection_mhc",
    col_wrap       = 12,
    heatmap_col    = c("0" = "blue", "1" = "red"),
    heatmap_name   = "Pathway\nIdentified",
    heatmap_legend_extra = list(at = c(0, 1), labels = c("No", "Yes")),
    padding_mm     = 40) |>
    cowplot::ggdraw()

  p_B4 <- plot_sc_time_space(panel_B4_data, text_size = text_size)
  # Unfortunately using harcode paths here
  # For each of these plots save to file
  save_plot_both(p_B1, here(output_dir, "fig_sc_b1_htx_auc_performance_bar_plot.png"))
  save_plot_both(p_B2, here(output_dir, "fig_sc_b2_htx_sig_pathways_count_plot.png"))
  save_plot_both(p_B3, here(output_dir, "fig_sc_b3_htx_pathway_identified_plot.png"))
  save_plot_both(p_B4, here(output_dir, "fig_sc_b4_htx_time_space_plot.png"))
  # ===============
  message("\n[plot_fig_sc_htx_panels_main] Done plotting fig sc htx panel")
}

plot_fig_sc_htx_panels_main(
  input_rds_path="data/processed/sc/sc_htx_plot_data_list.rds",
  output_dir="results/sc",
  text_size=12
)
