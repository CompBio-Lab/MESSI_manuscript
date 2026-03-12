# ==============================================================================
# process_sc_htx.R
# Create the plot data for the HTX dataset.
# ==============================================================================
source(here::here("src/fig_sc/sc_figure_utils.R"))

process_sc_htx <- function(metric_input_path=NULL, fgsea_input_path=NULL,
                                        trace_path=NULL, metadata_path=NULL,
                                        output_rds_path=NULL) {

  # Check for input paths
  if (is.null(metric_input_path)) {
    metric_input_path <- "data/raw/sc_data/htx_data/metrics.csv"
  }
  if (is.null(fgsea_input_path)) {
    fgsea_input_path <- "data/processed/sc/sc_htx_msigdbr_fgsea.csv"
  }
  if (is.null(trace_path)) {
    trace_path <- "data/raw/sc_data/htx_data/execution_trace.txt"
  }
  if (is.null(metadata_path)) {
    metadata_path <- "data/raw/sc_data/htx_data/parsed_metadata.csv"
  }

  if (is.null(output_rds_path)) {
    output_rds_path <- "data/processed/sc/sc_htx_plot_data_list.rds"
  }
  message("\n[process_sc_htx] Start to prepare plot data for figure sc htx panel")
  # -----------------------------
  # Configurations
  # Set DATASET to htx to filter
  DATASET         <- "htx"
  # Pattern to filter pathways from
  REJECTION_PATTERNS <- paste(
    c("mhc", "antigen presentation", "histocompatibility", "allograft",
      "t[- ]?cell", "b[- ]?cell", "interferon", "cytokine", "chemokine",
      "costimulation", "cd28", "ctla", "tcr", "adaptive immune",
      "nk cell", "natural killer", "complement", "immune response", "graft"),
    collapse = "|"
  )
  # ==============================
  # Common processing on data before plot
  auc_metric_df <- load_sc_auc_data(metric_input_path)
  # FGSEA pathways
  sc_fgsea_data <- load_sc_fgsea_data(
    fgsea_input_path ,
    group_columns   = c("method", "dataset", "celltype"),
    padj_group_vars = c("method", "dataset", "celltype")
  )


  # Now two things to get
  # Count of significant pathways in each method
  sig_pathways_count <- count_sc_sig_pathways(sc_fgsea_data, facet_var = NULL) %>%
    mutate(data_label = sc_fgsea_data$dataset %>% unique() %>%
             stringr::str_replace_all("_", " ") %>%
           stringr::str_to_title())

  # Pathways that are directly related allograft rejection
  classified <- classify_sc_pathways(sc_fgsea_data, REJECTION_PATTERNS,
                                     "allograft_rejection_mhc")
  # Last thing is the time space
  time_space_usage_df <- load_sc_time_space_data(
    trace_path = trace_path,
    metadata_path = metadata_path,
    dataset_patter = DATASET
  ) |>
    standardize_sc_time_space_methods()

  # ================================
  # Now store relevant plot data
  output_plot_data_list <- list(
    panel_c1_auc_plot_data = auc_metric_df,
    panel_c2_sig_pathways_count_plot_data = sig_pathways_count,
    panel_c3_pathway_identified_plot_data = classified,
    panel_c4_time_space_plot_data = time_space_usage_df
  )
  # And save it to file
  message("[process_sc_htx] Saving plot data to file: ", output_rds_path)
  saveRDS(output_plot_data_list, output_rds_path)
}

# Execute it
process_sc_htx(
  metric_input_path="data/raw/sc_data/htx_data/metrics.csv",
  fgsea_input_path="data/processed/sc/sc_htx_msigdbr_fgsea.csv",
  trace_path="data/raw/sc_data/htx_data/execution_trace.txt",
  metadata_path="data/raw/sc_data/htx_data/parsed_metadata.csv",
  output_rds_path="data/processed/sc/sc_htx_plot_data_list.rds"
)

