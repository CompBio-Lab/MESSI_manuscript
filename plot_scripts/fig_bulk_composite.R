# Combined all plots from multimodal
# Source the single scripts to update

library(cowplot)

src_scripts <- list.files("plot_scripts/", pattern = "fig4.*.R", full.names = T)
for (script in src_scripts) {
  source(script)
}

auc_perf <- readRDS("results/bulk/fig4b_bulk_auc_performance_heatmap.rds")
sig_pathways_count <- readRDS("results/bulk/fig4c_bulk_sig_pathways_bar_chart.rds")
organ_enr <- readRDS("results/bulk/fig4ef_bulk_panglao_organ_enrichment_heatmap.rds")
runtime <- readRDS("results/bulk/fig4g_bulk_runtime_vs_dataset_size.rds")
memory <- readRDS("results/bulk/fig4h_bulk_memory_vs_dataset_size.rds")


# ========================================================
# AUC left panel
# Middle top should be the sig pathway counts
# Middle bottom should be the panglao
# Third row Compute resources
# This should be a 2x2

middle <- plot_grid(
  sig_pathways_count + theme(legend.position = "none"),
  organ_enr,
  nrow = 2,
  rel_heights = c(0.3, 0.9),
  labels = c("C", "D")
)

bottom <- plot_grid(
  runtime  + theme(legend.position = "none"),
  memory  + theme(legend.position = "none"),
  nrow=2,
  labels=c("E", "F")
)




top <- plot_grid(auc_perf, middle, ncol=2,
                 rel_widths = c(0.5, 0.8),
                 labels=c("B", NULL))
out <- plot_grid(
  top, bottom, nrow=2, rel_heights = c(0.9, 0.4),
  align="hv"
)

# Width use 25 , height  = 18
ggsave("fig4_bulk_data_performances.png", out, width=20, height=16)


# # So arranging these as 4 columns?
# bottom_left <- plot_grid(
#   auc_perf,
#   sig_pathways_count +
#     theme(legend.position = "none"), ncol=2)
#
#
#
# bottom_right <- plot_grid(
#   runtime + theme(legend.position = "none"),
#   memory +
#     theme(legend.position = "none"),
#   nrow=2)
#
#
# bottom <- plot_grid(
#   bottom_left,
#   bottom_right,
#   ncol=2,
#   rel_widths = c(0.4,0.6)
# )
