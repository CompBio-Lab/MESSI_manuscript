# Combined all plots from multimodal


src_scripts <- list.files("plot_scripts/", pattern = "fig5.*.R", full.names = T)
for (script in src_scripts) {
  source(script)
}


library(cowplot)

auc_perf <- readRDS("results/multimodal/fig5b_multimodal_auc_performance_dot.rds")
prop_bar <- readRDS("results/multimodal/fig5f_multimodal_dataset_positive_prop_bar.rds")
sig_pathways_count <- readRDS("results/multimodal/fig5c_multimodal_sig_pathways_count.rds")
runtime <- readRDS("results/multimodal/fig5g_multimodal_runtime_vs_dataset_size.rds")
memory <- readRDS("results/multimodal/fig5h_multimodal_memory_vs_dataset_size.rds")
jaccard_ht <- readRDS("results/multimodal/fig5d_multimodal_jaccard_similarity_methods.rds")
top_pathway_ht <- readRDS("results/multimodal/fig5e_multimodal_top_pathways_identified_binary_heatmap.rds")

the_plot <- auc_perf +
  theme_bw(30) +
  ggtitle(NULL) +
  theme(legend.position = "none")

# the_plot <- sig_pathways_count +
#   theme_bw(16) +
#   ggtitle(NULL) +
#   theme(legend.position = "none")

# the_plot <- runtime +
#   theme_bw(16) +
#   ggtitle(NULL) +
#   theme(legend.position = "none")

# the_plot <- memory +
#   theme_bw(16) +
#   ggtitle(NULL) +
#   theme(legend.position = "none")

#ggsave("ppp.svg", jaccard_ht, width=8, height=6,dpi=1200)
#ggsave("ppp.svg", top_pathway_ht, width=8, height=6,dpi=1200)
ggsave("ppp.png", the_plot, width=8, height=7, dpi=1200)


# ==============================#
base_size <- 6

bottom_compute <- plot_grid(
  runtime +
    theme_bw(base_size = base_size) +
    theme(legend.position = "none"),
  memory +
    theme_bw(base_size = base_size) +
    theme(legend.position = "none"),
  nrow=2,
  labels=c("E", "F")
)

method_legend <- ggdraw(
  get_legend_35(
    sig_pathways_count +
      theme_bw(base_size = base_size + 0.25) +
      guides(
        fill=guide_legend(
          nrow=2,
          title=NULL
        ),
        shape = "none",
        color = "none"
      )
  )
)

# So arranging these as 4 columns?
bottom_right <- plot_grid(
  sig_pathways_count +
    theme_bw(base_size = base_size) +
    theme(legend.position = "none") +
    ggtitle(NULL),
  # Shared legend
  method_legend,
  # Continue plot
  bottom_compute,
  ncol=1,
  rel_heights = c(0.6, 0.08, 0.9),
  labels = c("D", NULL, NULL)
  )


bottom_left_top <- plot_grid(
  auc_perf +
    theme_bw(base_size = base_size) +
    theme(legend.position = "top") +
    guides(
      shape=guide_legend(
        nrow=2,
        title=NULL
      )
    ) +
    ggtitle(NULL),
  prop_bar,
  nrow=2,
  rel_heights = c(0.9, 0.25),
  labels=c("B", "C")
)


bottom_left <- plot_grid(
  bottom_left_top,
  bottom_right,
  ncol=2
  #labels = c(NU, NULL)
  )


bottom_middle <- plot_grid(
  jaccard_ht, top_pathway_ht,
  nrow = 2,
  rel_heights = c(0.55, 0.85),
  labels = c("G", "H")
)


# Now merge all
# ======================================================
# First merge the left + middle
comp_plots <- plot_grid(
  bottom_left,
  bottom_middle,
  ncol=2,
  rel_widths = c(0.4,0.6)
)

img_plot <- ggdraw() +
  draw_image("multimodal_design.png")


all_plot <- plot_grid(
  img_plot,
  comp_plots,
  nrow=2,
  rel_heights = c(0.45, 1),
  align="hv",
  labels=c("A", "")
)


ggsave("fig5_multimodal_data_performances.png",
       all_plot, width = 12, height = 12,
       bg="white")

