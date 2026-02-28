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


# =============================================================================
# Compute resources part
make_vertical_label <- function(label, base_size=8) {
  ggplot() +
    geom_rect(aes(xmin = 0, xmax = 1, ymin = 0, ymax = 1),
              fill = "white", color = NA) +
    annotate("text",
             x = 0.5, y = 0.5,
             label = label,
             angle = 90,
             size = base_size - 5
             ) +
    theme_void() +
    theme(
      plot.margin = margin(t = 5, r = 0, b = 5, l = 5)
    )
}

# row_runtime <- plot_grid(
#   make_vertical_label("Runtime (seconds)"),
#   runtime  + xlab(NULL) + ylab(NULL) +
#   theme_bw(base_size = 8) +
#   theme(
#     legend.position = "none",
#     #plot.margin = margin(t = 5, r = 5, b = 5, l = 0),
#     axis.ticks.x = element_blank(),
#     axis.text.x = element_blank(),
#   ) + ggtitle(NULL),
#   ncol = 2,
#   rel_widths = c(0.02, 1)
#   #labels = c("E", "")
# )

# row_memory <- plot_grid(
#   make_vertical_label("Memory (MB"),
#   memory  + ylab(NULL) + theme_bw(base_size = 8) +
#     theme(
#       #plot.margin = margin(t = 5, r = 5, b = 5, l = 0),
#       legend.position = "none"
#   ),
#   ncol = 2,
#   rel_widths = c(0.02, 1)
#   #labels = c("F", "")
# )



row_runtime <- runtime  + xlab(NULL) +
  ylab("Runtime (Seconds)") +
  theme_bw(base_size = 8) +
  theme(
    legend.position = "none",
    #plot.margin = margin(t = 5, r = 5, b = 5, l = 0),
    axis.ticks.x = element_blank(),
    axis.text.x = element_blank(),
  ) + ggtitle(NULL)

row_memory <- memory  +
  ylab("Memory (MB)") +
  theme_bw(base_size = 8) +
  theme(
    #plot.margin = margin(t = 5, r = 5, b = 5, l = 0),
    legend.position = "none"
  )


bottom <- plot_grid(
  row_runtime,
  row_memory,
  nrow=2
)


# ==============================================================================

#organ_enr <- readRDS("results/bulk/fig4ef_bulk_panglao_organ_enrichment_heatmap.rds")

# middle <- plot_grid(
#   sig_pathways_count + theme_bw(base_size=6.5) + theme(legend.position = "none"),
#   organ_enr,
#   nrow = 2,
#   rel_heights = c(0.4, 1),
#   labels = c("C", "D")
# )


# top <- plot_grid(
#   auc_perf,
#   middle,
#   ncol=2,
#   rel_widths = c(0.7, 0.8),
#   labels=c("B", NULL)
#   )

# out <- plot_grid(
#   top, bottom, nrow=2, rel_heights = c(0.9, 0.4),
#   align="hv"
# )



# Another way
top_right <- plot_grid(
  sig_pathways_count + theme_bw(base_size=6.5) + theme(legend.position = "none"),
  bottom,
  nrow=2,
  rel_heights = c(0.8, 1),
  labels=c("B", NULL)
)

top <- plot_grid(
  auc_perf, top_right, ncol=2,
  rel_widths = c(1, 0.8)
)


out <- plot_grid(
  top,
  organ_enr,
  nrow=2, rel_heights = c(1, 1)
)

ggsave("aa.png", out, width=7, height=7, dpi=300, bg="white")


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
