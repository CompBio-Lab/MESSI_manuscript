# ==============================================================================
# bulk_multimodal_panels.R
# Generate all figure panels for the bulk/multimodal analysis.
# ==============================================================================
source(here::here("src/fig_join_bulk_multimodal/bulk_figure_utils.R"))

library(here)
library(ggplot2)

plot_fig_bulk_multimodal_panels_main <- function(input_rds_path=NULL, output_dir=NULL,
                                        text_size=48) {
  if (is.null(input_rds_path)) {
    input_rds_path <- "data/processed/bulk_multimodal/bulk_multimodal_plot_data_list.rds"
  }
  if (is.null(output_dir)) {
    output_dir <- "results/bulk_multimodal"
  }

  # Read in the data and get all plot data
  plot_data_list <- readRDS(input_rds_path)
  # ===============================
  # Extract all the plot data
  panel_b_data  <- plot_data_list$panel_b_auc_data
  panel_c_data  <- plot_data_list$panel_c_feat_cor_mat_data
  panel_d_data  <- plot_data_list$panel_d_sig_pathways_count_data
  panel_ef_data <- plot_data_list$panel_ef_panglao_data
  panel_g_data  <- plot_data_list$panel_g_computational_resources_data
  # NOTE: for heatmap plots, their sizes need to be smaller to make sure it fits

  # ==============================================================================
  # Panel: AUC boxplot with dataset points
  # ==============================================================================
  p_b <- plot_bulk_auc_boxplot(panel_b_data, text_size = text_size) +
    theme(legend.position = "none")
  # ==============================================================================
  # Panel: Feature correlation heatmap
  # ==============================================================================
  p_c <- build_bulk_feature_correlation_heatmap(panel_c_data, text_size = text_size - 6) |>
    cowplot::ggdraw()
  # ==============================================================================
  # Panel: Pathway enrichment — varying FDR cutoff lines
  # ==============================================================================
  p_d <- plot_bulk_pathways_vary_cutoff(panel_d_data, text_size = text_size)
  # ==============================================================================
  # Panel: PanglaoDB heatmap
  # ==============================================================================
  p_e <- build_bulk_panglao_heatmap(panel_ef_data, text_size = text_size - 6) |>
    cowplot::ggdraw()
  # ==============================================================================
  # Panel: PanglaoDB annotation bar
  # ==============================================================================
  p_f <- plot_bulk_panglao_annot_bar(panel_ef_data, text_size = text_size)
  # ==============================================================================
  # Panel: Resource complexity (runtime + memory vs dataset size)
  # ==============================================================================
  p_g <- plot_bulk_resource_complexity(panel_g_data, text_size = text_size)
  # Unfortunately using hardcode paths here
  # For each of these plots save to file
  save_plot_both(p_b, here(output_dir, "fig_bulk_multimodal_b_auc_performance_point_boxplot.png"))
  save_plot_both(p_c, here(output_dir, "fig_bulk_multimodal_c_feature_mean_correlation_heatmap.png"))
  save_plot_both(p_d, here(output_dir, "fig_bulk_multimodal_d_sig_pathways_count_plot.png"))
  save_plot_both(p_e, here(output_dir, "fig_bulk_multimodal_e_panglao_organ_tissue_heatmap.png"))
  save_plot_both(p_f, here(output_dir, "fig_bulk_multimodal_f_count_panglao_method.png"))
  save_plot_both(p_g, here(output_dir, "fig_bulk_multimodal_g_computational_resources_usage.png"))
  # ===============
  message("\n[plot_fig_bulk_multimodal_panels_main] Done plotting fig bulk multimodal panels")
}

plot_fig_bulk_multimodal_panels_main(
  input_rds_path = "data/processed/bulk_multimodal/bulk_multimodal_plot_data_list.rds",
  output_dir = "results/bulk_multimodal",
  text_size = 16
)



