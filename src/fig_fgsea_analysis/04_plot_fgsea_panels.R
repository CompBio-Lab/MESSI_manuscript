doc <- "

Plot FGSEA Panels.

Usage:
  04_plot_fgsea_panels.R [options]

Options:
  --part1_data_path=P1_PATH     Path to part 1 FGSEA plot data file.
  --part2_data_path=P2_PATH     Path to part 2 FGSEA plot data file.
  --output_path=OUTPUT_PATH     Directory to save the final plot.
  --width=WIDTH                 Width of the output figure [default: 12].
  --height=HEIGHT               Height of the output figure [default: 12].
"



# Load libraries
library(ggplot2)
library(cowplot)

main <- function(part1_data_path, part2_data_path, output_path, width, height) {
  if (is.null(part1_data_path)) {
    part1_data_path <- "data/processed/fig_fgsea_panel_a_plot_data.rds"
  }

  if (is.null(part2_data_path)) {
    part2_data_path <- "data/processed/fig_fgsea_panel_b_plot_data.rds"
  }

  if (is.null(output_path)) {
    output_path <- "results/figures/fig_fgsea_analysis_two_panels.png"
  }

  # Load plot data from msigdbr and plot data from panglaodb
  panel_a_data <- readRDS(here::here(part1_data_path))
  panel_b_data <- readRDS(here::here(part2_data_path))

  # Then put them two together
  fig_fgsea_analysis_plot <- plot_grid(
    panel_a_data +
      guides(fill="none") +
      xlab(NULL) +
      labs(title=NULL),
    NULL, # spacer
    panel_b_data,
    nrow = 3,
    rel_heights = c(0.45, 0.05,  1),
    labels = c("A", "", "B")
  )

  #fig_fgsea_analysis_plot

  ggsave(
    here::here(output_path),
    plot=fig_fgsea_analysis_plot,
    width=width,
    height=height,
    bg="white"
  )
  message("\nSaved final fgsea analysis plot into ", output_path)
}

opt <- docopt::docopt(doc)
main(part1_data_path=opt$part1_data_path,
     part2_data_path=opt$part2_data_path,
     output_path=opt$output_path,
     width=as.numeric(opt$width),
     height=as.numeric(opt$height))






#panel_a_data +
#  labs(title=NULL)
# Number of significant pathways (Mean +- SD)
# Evaluate the +- as latex symbol
# TRY fixing the lower bound of the ymin

# Add caption explain what oncogenic , reactome c2 and c6
# explain it further

#fig_fgsea_analysis_plot



