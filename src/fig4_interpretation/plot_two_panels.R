# Load libraries
library(ggplot2)
library(cowplot)

# Load plot data from msigdbr and
# plot data from panglaodb
panel_a_data <- readRDS("data/processed/fig_fgsea_panel_a_plot_data.rds")
panel_b_data <- readRDS("data/processed/fig_fgsea_panel_b_plot_data.rds")




#panel_a_data +
#  labs(title=NULL)
# Number of significant pathways (Mean +- SD)
# Evaluate the +- as latex symbol
# TRY fixing the lower bound of the ymin

# Add caption explain what oncogenic , reactome c2 and c6
# explain it further

#fig_fgsea_analysis_plot


# Then put them two together
fig_fgsea_analysis_plot <- plot_grid(
  panel_a_data +
    guides(fill="none") +
    xlab(NULL) +
    labs(title=NULL),
  panel_b_data,
  nrow = 2,
  rel_heights = c(0.45, 1),
  labels = c("A", "B")
)

width <- 12
height <- 12

#fig_fgsea_analysis_plot

ggsave(
  "results/figures/fig_fgsea_analysis_two_panels.png",
  plot=fig_fgsea_analysis_plot,
  width=width,
  height=height
  )
