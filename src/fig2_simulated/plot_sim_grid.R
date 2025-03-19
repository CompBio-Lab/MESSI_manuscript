# Load in plots from real data
library(dplyr)
library(ggplot2)
library(knitr)
library(here)
library(cowplot)


# TODO:
# - n and p varid leave as supplementary
# - remove n and p and have signal and cor as grid vary
# - Fill sequoia with the training data gene names and add dummy values like 0 into the gene cols
# Subpanels of simulated sensitivity grid be i, ii, iii
# Convenient variables
fig_path <- here("data/processed/")
# Figs on sim dataset
#comp_time_sim <- here(fig_path, "computational_time_sim.rds") |> readRDS()
feat_sel_sim <- here(fig_path, "feature_selection_sim.rds") |> readRDS()
perf_sim <- here(fig_path, "perf_evaluation_sim.rds") |> readRDS()

# Join the plot here
# 2 Row, first row 2 col, second row 1 col
# Perf and time together top, with feature sel bottom

plot_sim_grid <- plot_grid(
  perf_sim + theme(legend.position = "none"),
  feat_sel_sim,
  labels = c("A", "B"),
  ncol = 1,
  # vjust adjust label position vertically
  vjust = 3,
  # 1.2 or 1 works fine?
  rel_heights = c(1, 0.9)
)

width <- 16
height <- 18

ggsave("results/figures/fig_sim_grid.png", plot_sim_grid,
       width=width, height=height, bg = "white")

