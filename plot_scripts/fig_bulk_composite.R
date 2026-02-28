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


# =======================
# Parameter
base_size <- 6

# ========================================================
# AUC left panel
# Middle top should be the sig pathway counts
# Middle bottom should be the panglao
# Third row Compute resources
# This should be a 2x2

middle <- plot_grid(
  sig_pathways_count +
    theme_bw(base_size=base_size) +
    theme(legend.position = "none") + ggtitle(NULL),
  organ_enr,
  nrow = 2,
  rel_heights = c(0.45, 1.5),
  #hjust=c(-0.5, -31),
  #vjust=c(1.5, -7.7),
  #label_x = c(0, 0.5),
  #label_y = c(1, -0.5),
  labels = c("C", "D")
)

#middle

color_legend <- ( sig_pathways_count +
  theme_bw(base_size=base_size*1.5) +
  guides(fill=guide_legend(ncol=1)) +
  theme(
    legend.box = "vertical",
    legend.position = "right",
    legend.background = element_rect(
      colour = "black",
      fill = "white",
      linewidth = 0.5
      ))
) %>%
  get_legend_35() %>%
  ggdraw()

bottom <- plot_grid(
  runtime  +
    xlab(NULL) +
    theme_bw(base_size = base_size + 0.25) +
    theme(
      legend.position = "none",
      #plot.margin = margin(t = 5, r = 5, b = 5, l = 0),
      axis.ticks.x = element_blank(),
      axis.title.y = element_text(size=base_size-2),
      axis.text.x = element_blank(),
    ) + ggtitle(NULL),
  memory +
    theme_bw(base_size = base_size + 0.25) +
    theme(
      legend.position = "none",
      axis.title.y = element_text(size=base_size-2),
      #plot.margin = margin(t = 5, r = 5, b = 5, l = 0),
    ) + ggtitle(NULL),
  nrow=2,
  labels=c("E", "F"),
  vjust = c(1.5, 1)
)

#bottom

top <- plot_grid(auc_perf, middle, ncol=2,
                 rel_widths = c(0.65, 0.85),
                 labels=c("B", NULL))

comp_plots <- plot_grid(
  top, bottom, nrow=2, rel_heights = c(1, 0.3),
  align="hv"
)

img_plot <- ggdraw() +
  draw_image("bulk_design.png", x=-0.05)

top_row <- plot_grid(
  img_plot,
  color_legend + theme(plot.margin = margin(0, 0, 0, -20)),
  ncol=2, rel_widths = c(1.5,0.25),
  align = "hv",
  axis="lr"
)

out <- plot_grid(
  top_row,
  comp_plots,
  align="hv",
  rel_heights = c(0.5,1),
  nrow = 2,
  labels = c("A", "")
)


ggsave("fig4_bulk_data_performances.png", out, width=8, height=10, bg="white")


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
