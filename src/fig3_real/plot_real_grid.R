# Load in plots from real data
library(dplyr)
library(ggplot2)
library(knitr)
library(here)
library(cowplot)

# TODO:
# - add correlation values  > threshold
# - change color of the label, white to red for legend
# - change name to multiview


# Convenient variables
fig_path <- here("data/processed/")
# Figs on real dataset
comp_time_real <- here(fig_path, "computational_time_real.rds") |> readRDS()
feat_sel_real <- here(fig_path, "feature_selection_real.rds") |> readRDS()
perf_real <- here(fig_path, "perf_evaluation_real.rds") |> readRDS() |> ggplotify::as.ggplot()
# Figs on sim dataset
# comp_time_sim <- here(fig_path, "computational_time_sim.rds") |> readRDS()
# feat_sel_sim <- here(fig_path, "feature_selection_sim.rds") |> readRDS()
# perf_sim <- here(fig_path, "perf_evaluation_sim.rds") |> readRDS()

# Join the plot here
# 2 Row, first row 2 col, second row 1 col
# Time and Perf together top, with feature sel bottom
plot_real_grid_top_row <- plot_grid(
  perf_real, feat_sel_real,
  labels = c("A", "B"),
  hjust = -1,
  nrow = 1
)

plot_real_grid <- plot_grid(
  plot_real_grid_top_row, comp_time_real,
  labels = c("", "C"),
  ncol = 1,
  # vjust adjust label position vertically
  vjust = -3
)

width <- 12
height <- 12

ggsave("results/figures/fig_real_grid.png", plot_real_grid,
       width=width, height=height)

