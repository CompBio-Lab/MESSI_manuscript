# Figure 4 Enrichment signif pathways by method and gene set collection

library(dplyr)
library(ggplot2)
library(ggrepel)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))


plot_fig4c1_bulk_n_sig_pathway_vary_cutoff <- function(input_path=NULL,
                                                               output_path=NULL,
                                                               text_size=7) {
  if (is.null(input_path)) {
    input_path <- "data/processed/bulk/bulk_msigdbr_fgsea.csv"
  }

  if (is.null(output_path)) {
    output_path <-  "results/bulk/fig4c_bulk_sig_pathways_vary_cutoff.png"
  }

  message("Plot size is: ", text_size)
  message("\nUse size = 40 for bigger label and manual plot, use size = 7 for cowplot")
  # Constant path
  msigdbr_pathways <- readRDS("data/processed/pathways_db/msigdbr_pathways_collection.rds")
  # Main code
  df <- data.table::fread(input_path)

  # For the multimodal datasets should look at reactome pathways only
  msigdbr_df <- inner_join(
    df, msigdbr_pathways,
    by = c("pathway" = "gs_name")
  ) %>%
    #filter(gs_collection_name == "Reactome Pathways") %>%
    # Then in this one, need to readjust the pval later, so
    # rename its existing padj to another name
    dplyr::rename(old_padj = padj) %>%
    dplyr::select(-c("gs_collection")) %>%
    tidyr::separate_wider_delim(
      group, delim = " | ",
      names = c("method", "dataset", "view"),
      too_many = "merge", too_few = "align_start"
    ) %>%
    group_by(method, dataset, view) %>%
    mutate(padj = p.adjust(pval, method="BH")) %>%
    ungroup() %>%
    mutate(method = standardize_method_names(method),
           color_label = str_remove(method, "-.*") |> toupper()) %>%
    mutate(color_label = case_when(
      color_label == "CARET_MULTIMODAL" ~ "CARET",
      TRUE ~ color_label
    ))
   # Should use a common cutoff
  cutoff <- 0.2
  #cutoff <- 0.05
  message("\nUsing cutoff of: ", cutoff)

  thresholds <- c(0.001, 0.005, 0.01, 0.05, 0.1, 0.2, 0.5)

  sig_counts <- expand_grid(
    threshold = thresholds,
    method = unique(msigdbr_df$method),
    db = unique(msigdbr_df$gs_collection_name)
  ) %>%
    rowwise() %>%
    mutate(
      n_sig = sum(
        msigdbr_df$padj < threshold &
          msigdbr_df$method == method &
          msigdbr_df$gs_collection_name == db,
        na.rm = TRUE
      )
    )


  out_plot <- sig_counts %>%
    ggplot(
      aes(x = n_sig,y = threshold,color = method, group = method)) +
    geom_point(size = floor(text_size / 3)) +
    geom_line() +
    # Label at threshold = 0.2 (adjust if desired)
    geom_text_repel(
      data = sig_counts %>% filter(threshold == 0.2),
      aes(label = method),
      direction = "y",
      #hjust = 0,
      max.overlaps = Inf,
      hjust = "right",
      show.legend = FALSE,
      min.segment.length = 0,
      segment.linetype = 6,
      #xlim = c(-Inf, Inf), ylim = c(-Inf, Inf),
      box.padding = 0.5,
      size = floor(text_size / 2.4)
    ) +
    facet_wrap(~db) +
    theme_bw(text_size) +
    theme(
      legend.position = "none",
      axis.text.x = element_text(size = text_size),
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
    ) +
    labs(
      x = "Number of Significant Genes",
      y = "Adjusted p-value Threshold"
    ) +
    scale_y_reverse() +
    scale_x_log10()

  save_plot_both(out_plot, output_path, width=12, height=8)
  return(out_plot)
}



fig4c1 <- plot_fig4c1_bulk_n_sig_pathway_vary_cutoff(
  input_path = "data/processed/bulk/bulk_msigdbr_fgsea.csv",
  output_path =  "results/bulk/fig4c1_bulk_sig_pathways_vary_cutoff.png",
  text_size = 12
)


