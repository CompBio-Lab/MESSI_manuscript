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
library(ggplot2)

source(here::here("src/common_helpers.R"))


# ===========================================================================
# CUSTOM THEMES
real_data_theme <- function() {
  list(
    labs(x = "Dataset Size", y = "Computation time in seconds (log scale)", fill = "Method"),
      theme_classic(),
      theme(
        # Make sizing
        axis.text = element_text(size = text_size),
        axis.title = element_text(size = text_size + 2),
        legend.title = element_text(size = text_size + 2),
        legend.text = element_text(size = text_size),
        legend.position = "bottom"
      ),
    guides(fill=guide_legend(nrow=2)),
    ggtitle(label = "Computational Time for Real Datasets"),
      theme(plot.title = element_text(hjust = 0.5))
  )

}

sim_data_theme <- function() {
  list(
    ggtitle(label = "Computational Time for Simulated Datasets"),
    theme(plot.title = element_text(hjust = 0.5))
  )
}

# ===========================================================================
# PLOTTING FUNCTIONS
plot_base <- function(plot_df, x_col = "size_label", y_col = "raw_seconds", fill = "method", method_palette="Paired") {
  # Ensymbol these
  x_col <- ensym(x_col)
  y_col <- ensym(y_col)
  fill <- ensym(fill)

  plot_df %>%
    ggplot(aes(x=!!x_col, y = !!y_col, fill=!!fill)) +
    stat_boxplot(geom="errorbar") +
    geom_boxplot(outlier.color = "red", outlier.fill="red") +
    scale_y_log10(labels = scales::label_log()) +
    scale_fill_brewer(palette=method_palette)
}




plot_real <- function(plot_df, text_size, method_palette) {
  # Factors cannot be retained when reading from csv, so coerce them here
  base_plot <-  plot_df %>%
    mutate(size_label = factor(size_label, levels=c("Small", "Large"))) %>%
    plot_base(x_col = "size_label", y_col = "raw_seconds",
              fill = "method", method_palette = method_palette)
  return(base_plot)

}

plot_sim <- function(plot_df) {
  factor_cols <- c("n", "p", "signal", "corr")
  base_plot <- plot_df %>%
    mutate(across(all_of(factor_cols), as.factor)) %>%
    plot_base(x_col = "method", y_col = "raw_seconds", fill = "method")


aa <-   plot_df %>%
    as_tibble() %>%


plot_base(aa, x_col = "method", fill = "method") +
  theme_classic() +
  facet_grid(p ~ n , labeller = label_both)
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

# First load in data
plot_df <- data.table::fread(input_path)
#plot_df <- data.table::fread("data/processed/fig_computational_time_sim_plot_data.csv")

if (data_type == "real") {
  computation_time_plot <- plot_real(plot_df, text_size = text_size,
                                     method_palette = method_palette) +
    real_data_theme()
} else if (data_type == "sim") {
  computation_time_plot <- ggplot() + ggtitle("fake plot")
  #computation_time_plot <- plot_sim(plot_df, text_size = text_size,
  #                                  method_palette = method_palette) +
  #  sim_data_theme()
}
# Lastly save it
ggsave(output_path, plot=computation_time_plot,
       width=width, height=height, device=device, dpi=dpi,
       create.dir = TRUE)
message("Saved image of ", width, " x ", height, " to ", output_path)


#computation_time_plot
