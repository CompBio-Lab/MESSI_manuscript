# ===============================================
source(here::here("src/common_helpers/map_disease_name.R"))
source(here::here("src/common_helpers/standardize_data_funs.R"))

plot_fig_join_bulk_multimodal_auc_boxplot_point <- function(output_path=NULL, text_size=7) {
  if (is.null(output_path)) {
    output_path <- "results/join_bulk_multimodal/fig_join_bulk_multimodal_auc_boxplot_point.png"
  }
  # A good size for this plot should be:
  # text_size <- 17
  # ==================
  # Main code her
  bulk_metric_df <- data.table::fread("data/raw/bulk_data/metrics.csv") |>
    dplyr::rename(method = method_name) |>
    dplyr::select(method, dataset, auc)
  # Load multimodal data
  multimodal_metric_df <- data.table::fread("data/raw/multimodal_data/metrics.csv") |>
    dplyr::rename(method = method_name) |>
    dplyr::select(method, dataset, auc)

  # Combined both
  combined_df <- bind_rows(bulk_metric_df, multimodal_metric_df)  |>
    # Drop kipan and chol for the bulk
    filter(!dataset %in% c("tcga-chol", "tcga-kipan")) %>%
    mutate(dataset = map_disease_name(tolower(dataset)),
           method = standardize_method_names(method)) %>%
    # For performance plots dont show the comp1 or factor 1 models
    filter(!str_detect(method, "1"))

  #library(ggpubr)


  # # Option 1: Compare everything against a reference method
  # my_comparisons <- list(
  #   c("DIABLO-N2", "DIABLO-F2"),
  #   c("DIABLO-N2", "MOGONET"),
  #   c("DIABLO-N2", "caret_Multimodal"),
  #   c("DIABLO-N2", "IntegrAO")
  # )
  out_plot <- combined_df %>%
    ggplot(aes(x = fct_reorder(method, auc), y = auc)) +
    # Green-tinted high performance zone
    #annotate("rect", xmin = -Inf, xmax = Inf, ymin = 0.95, ymax = 1.0,
    #         fill = "#d4edda", alpha = 0.3) +
    #annotate("text", x = Inf, y = 0.975, label = "AUC ≥ 0.95",
    #         size = 2.5, color = "gray40", fontface = "italic",
    #         vjust=2.5) +
    # Reference line at 0.5
    geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray50") +
    # Whiskers
    geom_errorbar(stat = "boxplot", width = 0.3, linewidth = 0.3, color = "gray50") +
    # Gray boxplot
    geom_boxplot(color = "gray50", fill = NA, outlier.shape = NA,
                 width = 0.5, linewidth = 0.3) +
    # Subtle connecting lines
    geom_line(aes(group = dataset, color = dataset),
              alpha = 0.25, linewidth = 0.3) +
    # Colored points on top
    geom_point(aes(color = dataset), size = 2.5, alpha = 0.7) +
    # Color palette
    ggsci::scale_color_d3(palette = "category20") +
    coord_flip() +
    labs(x = "Method", y = "AUC", color = "Dataset") +
    theme_bw(base_size=text_size) +
    theme(
      #legend.key.size = unit(0.4, "cm"),
      panel.grid.major.y = element_blank(),
      panel.grid.minor = element_blank(),
      legend.position = "bottom",
      legend.margin = margin(r=100)
    ) +
    guides(color=guide_legend(nrow=4))
  # Lastly save it
  save_plot_both(out_plot, output_path, width=12, height=8)
  return(out_plot)
}

plot_fig_join_bulk_multimodal_auc_boxplot_point(
  output_path="results/join_bulk_multimodal/fig_join_bulk_multimodal_auc_boxplot_point.png",
  text_size=7
)

