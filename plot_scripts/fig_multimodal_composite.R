# Combined all plots from multimodal


src_scripts <- list.files("plot_scripts/", pattern = "fig5.*.R", full.names = T)
for (script in src_scripts) {
  source(script)
}


library(cowplot)

auc_perf <- readRDS("results/multimodal/fig5b_multimodal_auc_performance_dot.rds")
sig_pathways_count <- readRDS("results/multimodal/fig5c_multimodal_sig_pathways_count.rds")
runtime <- readRDS("results/multimodal/fig5g_multimodal_runtime_vs_dataset_size.rds")
memory <- readRDS("results/multimodal/fig5h_multimodal_memory_vs_dataset_size.rds")
jaccard_ht <- readRDS("results/multimodal/fig5d_multimodal_jaccard_similarity_methods.rds")
top_pathway_ht <- readRDS("results/multimodal/fig5e_multimodal_top_pathways_identified_binary_heatmap.rds")



# So arranging these as 4 columns?
bottom_right <- plot_grid(
  sig_pathways_count +
    theme(legend.position = "none") +
    ggtitle(NULL),
  runtime + theme(legend.position = "top"),
  memory +
    theme(legend.position = "none"),
  nrow=3,
  labels = c("C", "D", "E")
  )




bottom_left <- plot_grid(
  auc_perf +
    theme(legend.position = "bottom"),
  bottom_right,
  ncol=2,
  labels = c("B", NULL)
  )


bottom_middle <- plot_grid(
  jaccard_ht, top_pathway_ht,
  nrow = 2,
  rel_heights = c(0.55, 0.85),
  labels = c("F", "G")
)


# Now merge all
# First merge the left + middle
bottom <- plot_grid(
  bottom_left,
  bottom_middle,
  ncol=2,
  rel_widths = c(0.4,0.6)
)

ggsave("fig5_multimodal_data_performances.png", bottom, width = 25, height = 15)
