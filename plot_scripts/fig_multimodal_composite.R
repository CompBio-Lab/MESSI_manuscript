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



bottom_compute <- plot_grid(
  runtime + theme(legend.position = "none"),
  memory +
    theme(legend.position = "none"),
  nrow=2,
  labels=c("E", "F")
)

method_legend <- ggdraw(
  get_legend_35(
    sig_pathways_count +
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
    theme(legend.position = "bottom"),
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
# First merge the left + middle
bottom <- plot_grid(
  bottom_left,
  bottom_middle,
  ncol=2,
  rel_widths = c(0.4,0.6)
)

ggsave("fig5_multimodal_data_performances.png",
       bottom, width = 25, height = 15,
       bg="white")

