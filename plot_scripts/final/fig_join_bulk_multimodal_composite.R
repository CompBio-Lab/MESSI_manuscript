library(cowplot)
library(ggplot2)
source("src/common_helpers/plot_utils.R")

# ==============================================================================
# The join bulk and multimodal datasets figures

# ===========================================
# 1st ROW
# ===========================================
# Panel A
# The study design join with the legend of colors (method family)
study_design <- ggdraw() +
  draw_image("bulk_design.png", x=-0.05)
# ===========================================
# 2ND ROW
# ===========================================
# Panel B
# Joined performance comparison of auc
# Boxplot + point + line
auc_perf <- readRDS("results/join_bulk_multimodal/fig_join_bulk_multimodal_auc_boxplot_point.rds")
# ===========================================
# 3RD ROW
# Feature importance heatmap for the multimodal ones
# =================================================
multimodal_jaccard_ht <- readRDS("results/multimodal/fig5d_multimodal_jaccard_similarity_methods.rds")

# 4TH ROW
multimodal_binary_ht <- readRDS("results/multimodal/fig5e_multimodal_top_pathways_identified_binary_heatmap.rds")


# 3RD ROW
# ===========================================
# N sig vary cutoff of reactome + oncogenic
objs <- readRDS("results/join_bulk_multimodal/fig_join_bulk_multimodal_n_sig_pathways_vary_cutoff.rds")
# ===========================================
# 4TH ROW
# ===========================================
# Tissue of origin panglao (but this one is only from bulk)
# Left: heatmap
# righ: annotation bar count
panglao_origin <- readRDS("results/bulk/fig4ef_bulk_panglao_organ_enrichment_heatmap.rds")
panglao_annot_bar <- readRDS("results/join_bulk_multimodal/fig_join_bulk_multimodal_panglao_annot_count_bar.rds")
# ===============================================
# 5TH ROW
# ===============================================
# Time and Space complexity
resource_complexity <- readRDS("results/join_bulk_multimodal/fig_join_bulk_multimodal_resource_complexity.rds")
# ===========================================================
# So now combine all
# Final sizing
text_size <- 16

dataset_legend <- get_legend_35(
  auc_perf + theme_bw(text_size) +
    guides(
     color = guide_legend(direction = "vertical")
    )
) |> ggdraw()

method_legend <-  get_legend_35(
  resource_complexity + theme_bw(text_size+4) +
    guides(
      color = guide_legend(direction = "horizontal", nrow=1)
    )
) |> ggdraw()


top_row <- plot_grid(
  study_design, dataset_legend, nrow=1, rel_widths = c(1, 0.05)
)


panglao_row <- plot_grid(
  panglao_origin, panglao_annot_bar + theme(legend.position = "none"), nrow=1
)

out_plot <- plot_grid(
  top_row,
  auc_perf + theme_bw(text_size) + theme(
    legend.position = "none"
  ),
  multimodal_jaccard_ht,
  multimodal_binary_ht,
  objs + theme_bw(text_size) + theme(
    legend.position = "none"
  ),
  panglao_row,
  # Then add the legend of the methods
  method_legend,
  resource_complexity + theme_bw(text_size) +
    theme(
      legend.position = "none",
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      panel.grid.minor.y = element_line(linewidth = 0.3, color = "grey85"),
      plot.margin = margin(5, 40, 5, 5)
  ),
  ncol=1,
  rel_heights = c(1,1,1,1,1,1,0.05,1),
  labels=c("A", "B", "C", "D", "E", "F", "", "G")
)

ggsave("fig_join_bulk_multimodal.pdf", out_plot, width=15, height=49, bg="white", dpi=700)

#ggsave("fig_join_bulk_multimodal.png", out_plot, width=12, height=24, bg="white", dpi=700)

