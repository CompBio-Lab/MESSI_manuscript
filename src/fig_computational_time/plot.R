doc <- "

This script is used to create figure 2 of computational time.

Usage:
  plot.R [options]

Options
  --input_path=INPUT_PATH     Path to read plot data
  --output_path=OUTPUT_PATH   Path to write out computational time
  --width=WIDTH               Width of the graph [default: 7]
  --height=HEIGHT             Height of the graph [default: 7]
  --device=DEVICE             Device to print out [default: png]
  --dpi=DPI                   Dots per inch [default: 300]
  --data_type=DATA_TYPE       Type of data to processed. One of real, sim [default: real]
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
#library(purrr)
library(ggplot2)
#library(stringr)
#library(tidyr)

real_data_theme <- function() {
  list(
    ggtitle(label = "Computational Time for Real Datasets") +
      theme(plot.title = element_text(hjust = 0.5))
  )

}

sim_data_theme <- function() {
  ggtitle(label = "Computational Time for Simulated Datasets") +
    theme(plot.title = element_text(hjust = 0.5))
}


main <- function(input_path, output_path, data_type) {
  # Load the plot data
  plot_df <- read.csv(input_path)


  # Plotting starts here
  base_plot <- plot_df %>%
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

  if (data_type == "real") {
    computation_time_plot <- base_plot + real_data_theme()
  } else if (data_type == "sim") {
    computation_time_plot <- base_plot + sim_data_theme()
  }
  # Lastly save it
  ggsave(output_path, plot=computation_time_plot,
        width=width, height=height, device=device, dpi=dpi,
        create.dir = TRUE)
  message("Saved image of ", width, " x ", height, " to ", output_path)

}

# Parse cli
opt <- docopt::docopt(doc)

# Convenient vars
input_path <- opt$input_path
output_path <- opt$output_path
data_type <- opt$data_type


# Plotting params
width <- as.numeric(opt$width)
height <- as.numeric(opt$height)
device <- opt$device
dpi <- as.numeric(opt$dpi)
text_size <- 12
method_palette <- "Paired"

# Lastly execute the main function
main(input_path = input_path, output_path = output_path, data_type = data_type)
