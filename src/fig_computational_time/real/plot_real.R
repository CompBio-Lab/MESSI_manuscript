doc <- "

This script is used to create figure 2 of computational time for real datasets.

Usage:
  plot_real.R [options]

Options
  --input_path=INPUT_PATH     Path to read plot data
  --output_path=OUTPUT_PATH   Path to write out computational time
  --width=WIDTH               Width of the graph [default: 7]
  --height=HEIGHT             Height of the graph [default: 7]
  --device=DEVICE             Device to print out [default: png]
  --dpi=DPI                   Dots per inch [default: 300]
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

source(here::here("src/common_helpers.R"))
source(here::here("src/fig_computational_time/_comp_time_utils.R"))

# ===========================================================================
# CUSTOM THEMES
real_data_theme <- function(text_size) {
  list(
    labs(x = "Dataset Size", y = "Computation time in seconds (log scale)", fill = "Method"),
    ggtitle(label = "Computational Time for Real Datasets"),
    theme_classic(),
    theme(
      # Make sizing
      axis.text = element_text(size = text_size),
      axis.title = element_text(size = text_size + 2),
      legend.title = element_text(size = text_size + 2),
      legend.text = element_text(size = text_size),
      legend.position = "bottom",
      plot.title = element_text(hjust = 0.5)
    ),
    guides(fill=guide_legend(nrow=2))
  )

}

# ===========================================================================


# Create the base plot for real data
plot_real <- function(plot_df, method_palette) {
  # Factors cannot be retained when reading from csv, so coerce them here
  base_plot <-  plot_df %>%
    mutate(size_label = factor(size_label, levels=c("Small", "Large"))) %>%
    plot_base(x_col = "size_label", y_col = "raw_seconds",
              fill = "method", method_palette = method_palette)
  return(base_plot)

}


# ==============================================================================
# MAIN LOGIC OF PLOTTING
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

# First load in data
plot_df <- data.table::fread(input_path)
#plot_df <- data.table::fread("data/processed/fig_computational_time_sim_plot_data.csv")


computation_time_plot <- plot_real(plot_df, method_palette = method_palette) +
  real_data_theme(text_size = text_size)

# Lastly save it
ggsave(output_path, plot=computation_time_plot,
       width=width, height=height, device=device, dpi=dpi,
       create.dir = TRUE)

# Also save this to RDS for further processing
saveRDS(computation_time_plot,
        file = here::here("data/processed/computational_time_real.rds")
)
message("Saved image of ", width, " x ", height, " to ", output_path)

