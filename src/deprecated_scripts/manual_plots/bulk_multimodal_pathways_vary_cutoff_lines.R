# Figure 4 Enrichment signif pathways by method and gene set collection

library(dplyr)
library(ggplot2)
library(ggrepel)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))


plot_fig_join_bulk_multimodal_n_sig_pathway_vary_cutoff <- function(
    output_path=NULL,
    text_size=7) {
  if (is.null(output_path)) {
    output_path <-  "results/join_bulk_multimodal/fig_join_bulk_multimodal_n_sig_pathways_vary_cutoff.png"
  }

  message("Plot size is: ", text_size)
  message("\nUse size = 40 for bigger label and manual plot, use size = 7 for cowplot")
  # Constant path
  msigdbr_pathways <- readRDS("data/processed/pathways_db/msigdbr_pathways_collection.rds")
  # Main code
  # Load the one from multimodal
  multimodal_df <- data.table::fread("data/processed/multimodal/multimodal_msigdbr_fgsea.csv")
  bulk_df <- data.table::fread("data/processed/bulk/bulk_msigdbr_fgsea.csv")

  j1 <- inner_join(multimodal_df, msigdbr_pathways, by=c("pathway"="gs_name"))
  j2 <- inner_join(bulk_df, msigdbr_pathways, by=c("pathway"="gs_name"))
  # Then bind rows from both
  msigdbr_df <- bind_rows(j1, j2) %>%
    # Then in this one, need to readjust the pval later, so
    # rename its existing padj to another name
    dplyr::select(-c("gs_collection", "ES", "NES", "size")) %>%
    dplyr::rename(old_padj = padj) %>%
    # And creat the dataset and view from here
    tidyr::separate_wider_delim(
      group, delim = " | ",
      names = c("method", "dataset", "view"),
      too_many = "merge", too_few = "align_start"
    ) %>%
    group_by(method, dataset, view) %>%
    mutate(padj = p.adjust(pval, method="BH")) %>%
    ungroup() %>%
    # Then standardize method name here
    mutate(method = standardize_method_names(method)) %>%
    # TODO: fix here later, manually removing the label of FA in mofa
    mutate(method = str_replace(method, "MOFA-FA", "MOFA-") |>
             str_replace("lda", "LDA"))


  # Should use a common cutoff
  cutoff <- 0.2
  #cutoff <- 0.05
  message("\nUsing cutoff of: ", cutoff)

  thresholds <- c(0.001, 0.005, 0.01, 0.05, 0.1, 0.2, 0.5)

  sig_counts <- expand.grid(
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


  # =======================================
  # Change the text size to look a bigger plot
  out_plot <- sig_counts %>%
    ggplot(
      aes(x = n_sig,y = threshold,color = method, group = method)) +
    geom_point(size = floor(text_size / 5.2), alpha=0.5) +
    geom_line() +
    # Label at threshold = 0.2 (adjust if desired)
    geom_text_repel(
      data = sig_counts %>% filter(threshold == 0.2),
      aes(label = method),
      direction = "both",
      alpha=NA,
      #hjust = 0,
      #force=2,
      #force_pull = 1,
      max.overlaps = Inf,
      #hjust = "right",
      show.legend = FALSE,
      segment.size = 0.3,
      #max.iter = 20000,
      min.segment.length = 0,
      force=5,
      box.padding = 0.75,
      nudge_x=-0.25,
      nudge_y=-0.05,
      arrow = arrow(length = unit(0.015, "npc")),
      #position = position_nudge_repel(x = -2, y=-0.1),
      #segment.linetype = 6,
      #xlim = c(-Inf, Inf), ylim = c(-Inf, Inf),
      #box.padding = 0.5,
      size = floor(text_size / 4.5)
    ) +
    facet_wrap(~db, scales = "free", nrow=2) +
    theme_bw(text_size) +
    theme(
      legend.position = "none",
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank(),
    ) +
    labs(
      x = "Number of Significant Pathways",
      y = "Adjusted p-value Threshold"
    ) +
    scale_color_manual(values=method_colors) +
    scale_y_reverse() +
    scale_x_log10()

  save_plot_both(out_plot, output_path, width=12, height=8)
  return(out_plot)
}
# Use text size of 36
the_plot <- out_plot +
  ylab("FDR threshold") +
  theme(legend.position = "none")

out_plot <- plot_fig_join_bulk_multimodal_n_sig_pathway_vary_cutoff(
  output_path =  "results/join_bulk_multimodal/fig_join_bulk_multimodal_n_sig_pathways_vary_cutoff.png",
  text_size = 48
)


ggsave("aaa.svg", the_plot, width=18, height=10, bg="white", dpi=1200)




