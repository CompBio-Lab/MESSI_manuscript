doc <- "

This script is used to create figure 2 of computational time.

Usage:
  plot.R [options]
  --input_csv=INPUT_CSV       Path to read plot data
  --output_path=OUTPUT_PATH   Path to write out computational time
  --width=WIDTH               Width of the graph [default: 7]
  --height=height             Height of the graph [default: 7]
  --device=DEVICE             Device to print out [default: png]
  --dpi=DPI                   Dots per inch [default: 300]
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(purrr)
library(ggplot2)
library(stringr)
library(tidyr)


main <- function(input_path, output_path) {
  # Load the plot data
  plot_df <- read.csv(input_path)


  # Plotting starts here
  computation_time_plot <- plot_df %>%
    ggplot(aes(x=size_label, y = raw_seconds, fill=method)) +
    stat_boxplot(geom="errorbar") +
    geom_boxplot(outlier.color = "red", outlier.fill="red") +
    scale_y_log10(labels = scales::label_log()) +
    scale_fill_brewer(palette=method_palette) +
    labs(x = "Dataset Size", y = "Computation time in seconds (log scale)", fill = "Method") +
    theme_classic() +
    theme(
      # Make sizing
      axis.text = element_text(size = text_size),
      axis.title = element_text(size = text_size + 2),
      legend.title = element_text(size = text_size + 2),
      legend.text = element_text(size = text_size),
      legend.position = "bottom"
    ) +
    guides(fill=guide_legend(nrow=2))
  # Lastly save it
  ggsave(output_path, plot=computation_time_plot,
        width=width, height=height, device=device, dpi=dpi,
        create.dir = TRUE)
  message("Saved image of ", width, " x ", height, " to ", output_path)

}

# Parse cli
opt <- docopt::docopt(doc)

# Convenient vars
input_path <- opt$input_csv
output_path <- opt$output_path


# Plotting params
width <- as.numeric(opt$width)
height <- as.numeric(opt$height)
device <- opt$device
dpi <- as.numeric(opt$dpi)
text_size <- 12
method_palette <- "Paired"

# Lastly execute the main function
main(input_path = input_path, output_path = output_path)
