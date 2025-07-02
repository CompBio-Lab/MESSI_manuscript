library(cowplot)

aa <- "data/new_processed"
real <- readRDS("data/processed/computational_time_real.rds")
sim <- readRDS("data/processed/computational_time_sim.rds")


get_legend_35 <- function(plot) {
  # return all legend candidates
  legends <- get_plot_component(plot, "guide-box", return_all = TRUE)
  # find non-zero legends
  nonzero <- vapply(legends, \(x) !inherits(x, "zeroGrob"), TRUE)
  idx <- which(nonzero)
  # return first non-zero legend if exists, and otherwise first element (which will be a zeroGrob)
  if (length(idx) > 0) {
    return(legends[[idx[1]]])
  } else {
    return(legends[[1]])
  }
}


shared_legend <- get_legend_35(
  real +
    guides(fill = guide_legend(nrow = 1)) +
    theme(
      legend.direction = "horizontal",
      legend.justification="center" ,
      legend.box.just = "bottom"
    )
)

text_size <- 8

top_row <- plot_grid(
  sim + theme(legend.position = "none") + xlab(NULL) + theme(
    axis.title = element_text(size = text_size),
    plot.title = element_text(size = text_size + 2)
  ),
  real + theme(legend.position = "none") + theme(
    axis.title = element_text(size = text_size),
    plot.title = element_text(size = text_size + 2)
  )
)

top_row
ccc <- plot_grid(top_row, shared_legend, ncol = 1, rel_heights = c(0.7, .1))

ggsave(filename="new_comp_time.png", plot=ccc, width=8, height=4)
# plot_sim_grid <- plot_grid(
#   plot_sim_grid_top_row, feat_sel_sim,
#   labels = c("", "C"),
#   ncol = 1,
#   # vjust adjust label position vertically
#   vjust = 3,
#   # 1.2 or 1 works fine?
#   rel_heights = c(1, 0.9)
# )
#
#
# plot_sim_grid_top_row <- plot_grid(
#   perf_sim + theme(legend.position = "none"),
#   comp_time_sim + theme(legend.position = "none") + xlab(NULL),
#   labels = c("A", "B"),
#   hjust = -1,
#   nrow = 1
# )
