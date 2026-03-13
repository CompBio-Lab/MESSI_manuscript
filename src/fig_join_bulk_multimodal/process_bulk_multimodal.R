# ==============================================================================
# bulk_multimodal_panels.R
# Generate all figure panels for the bulk/multimodal analysis.
# ==============================================================================
source(here::here("src/fig_join_bulk_multimodal/bulk_figure_utils.R"))

process_bulk_multimodal <- function(output_rds_path=NULL) {
  if (is.null(output_rds_path)) {
    output_rds_path <- "data/processed/bulk_multimodal/bulk_multimodal_plot_data_list.rds"
  }
  if (!dir.exists(dirname(output_rds_path))) dir.create(dirname(output_rds_path),
                                                        recursive = T)
  # Load all the required plot data for bulk multimodal figure
  # Panel B auc metric
  bulk_auc_df <- load_bulk_auc_data(
    bulk_path       = "data/raw/bulk_data/metrics.csv",
    multimodal_path = "data/raw/multimodal_data/metrics.csv"
  )
  # ==========================================
  # Panel C Feature mean correlation
  feature_cor_mat <- load_bulk_feature_correlation(
    bulk_path       = "data/raw/bulk_data/all_feature_selection_results.csv",
    multimodal_path = "data/raw/multimodal_data/all_feature_selection_results.csv"
  )

  # ===========================================
  # Panel D Number of significant pathways vary cutoff
  sig_pathway_counts <- load_bulk_fgsea_data(
    bulk_fgsea_path       = "data/processed/bulk/bulk_msigdbr_fgsea.csv",
    multimodal_fgsea_path = "data/processed/multimodal/multimodal_msigdbr_fgsea.csv",
    msigdbr_path          = "data/processed/pathways_db/msigdbr_pathways_collection.rds"
  ) |>
    count_bulk_sig_pathways()

  # ===========================================
  # Panel E, F Panglao DB, organ-tissue matching pathways
  panglao_data <- load_bulk_panglao_data(
    fgsea_path    = "data/processed/bulk/bulk_panglao_fgsea.csv",
    panglao_path  = "data/processed/pathways_db/panglao_pathways_collection.rds",
    drop_datasets = c("tcga-kipan")
  )

  # ===========================================
  # Panel G Computation Resources Complexity
  bulk_cx <- load_bulk_complexity("data/raw/bulk_data/")
  mm_cx   <- load_bulk_complexity("data/raw/multimodal_data/")

  combined_cx <- bind_rows(bulk_cx, mm_cx) %>%
    filter(!dataset_name %in% c("tcga-chol", "tcga-kipan")) %>%
    standardize_bulk_resource_methods()

  # Lastly output all data as list
  output_plot_data_list <- list(
    panel_b_auc_data = bulk_auc_df,
    panel_c_feat_cor_mat_data = feature_cor_mat,
    panel_d_sig_pathways_count_data = sig_pathway_counts,
    panel_ef_panglao_data = panglao_data,
    panel_g_computational_resources_data = combined_cx
  )
  saveRDS(output_plot_data_list, output_rds_path)
  message("\n[process_bulk_multimodal] Saved data into: ", output_rds_path)
}

# Execute it
process_bulk_multimodal(
  output_rds_path = "data/processed/bulk_multimodal/bulk_multimodal_plot_data_list.rds"
)




