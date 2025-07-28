doc <- "

This script is used to create figure of computational resources usage for real data

Usage:
  plot_sim.R [options]

Options:
  --input_path=INPUT      Path to read in the plot data
  --output_path=OUTPUT    Path to write out output plot
  --width=WIDTH           Width of the graph [default: 7]
  --height=height         Height of the graph [default: 7]
  --device=DEVICE         Device to print out [default: png]
  --dpi=DPI               Dots per inch [default: 300]
  --show_title=ST         Show plot title [default: 1]
"



# Load libraries
library(ggplot2)
library(forcats)
suppressPackageStartupMessages(library(dplyr))
library(cowplot)


# Load custom scripts
source("src/fig_computational_resources_usage/_utils.R")


# Custom theme to use
resource_panel_theme <- function(text_size) {
  # Remove the vertical lines in x-axis
  theme(
    legend.title = element_text(size = text_size + 2),  # Change title text size
    legend.text = element_text(size = text_size),    # Change label text size
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.background = element_rect(fill = "grey95", color = "grey70"),
    panel.spacing.y = unit(1, "lines"),     # Increase vertical spacing
    strip.text.x = element_text(size=text_size + 2, face = "bold"),
    strip.text.y = element_text(size=text_size)
    #strip.placement = "outside"             # Optional: keeps strip outside the panel
  )
}



plot_summary_metric <- function(data, metric_col, metric_label, y_lab, text_size, alpha=0.5, use_log=FALSE) {
  # The metric is summarized
  # Compute mean and sd for the metric
  summary_df <- data %>%
    mutate(metric = metric_label) %>%
    group_by(method, action, metric) %>%
    summarize(
      mean_val = mean(.data[[metric_col]]),
      sd_val = sd(.data[[metric_col]]),
      .groups = "drop"
    )

  # Reorder methods by mean_val descending
  summary_df <- summary_df %>%
    mutate(method = fct_reorder(method, -mean_val))

  # This vector value is for new label of action
  action_labels <- c(
    "PREPROCESS" = "Preprocess",
    "TRAIN" = "Train Model",
    "PREDICT" = "Predict",
    "FEATURE_SELECT" = "Feature Selection"
  )

  # Base Plot
  p <- ggplot(summary_df, aes(x = method, y = mean_val, fill = action)) +
    geom_bar(stat = "identity", width = 0.4, alpha = alpha) +
    geom_errorbar(aes(ymin = mean_val - sd_val, ymax = mean_val + sd_val), width = 0.2) +
    scale_fill_manual(
      values = c(
        "#E69F00",  # orange
        "#56B4E9",  # sky blue
        "#009E73",  # bluish green
        "#CC79A7"   # reddish purple)
      ),
      labels = action_labels
    ) +
    theme_bw(base_size = text_size) +
    # Relies on another theme function
    resource_panel_theme(text_size) +
    ggh4x::facet_grid2(
      action ~ metric,
      scales = "free_y",
      independent = "y",
      labeller = labeller(action = action_labels)
    )
  # Determine to use if log or not
  if (use_log) {
    y_lab <- paste0(y_lab, "Log 10 scale")
    p <- p +
        scale_y_continuous(
          trans = "log10",
          labels = scales::label_log(),
          expand = expansion(mult = c(0, 0.5))
          )
  }
  # Lastly add the label and output
  return(p + labs(x="", y = y_lab))
}




# Main execute point of the script
main <- function(input_path, output_path, text_size, width, height, dpi, use_log=FALSE) {
  if (is.null(input_path)) {
    input_path <- "data/processed/computational_resources_usage_df.csv"
  }

  if (is.null(output_path)) {
    output_path <- "results/figures/fig_computational_resources_usage.png"
  }

  # Load data
  plot_df <- data.table::fread(here::here(input_path))

  # Plot the individual panels with raw scale (useLog=FALSE)

  # The time plot
  time_plot <- plot_summary_metric(
    plot_df, "duration_sec", "Duration", y_lab = "Duration (seconds)",
    text_size=text_size,
    use_log=use_log
    )

  # The memory plot
  memory_plot <- plot_summary_metric(
    plot_df, "peak_vmem_mb", "Memory", y_lab = "RAM memory usage (MB)",
    text_size=text_size,
    use_log=use_log
    )

  # Combine individual plots and remove legend
  p_without_legend <- plot_grid(
    time_plot + theme(legend.position = "none",
                   strip.text.y = element_blank()),
    memory_plot + theme(legend.position = "none"),
    ncol=2,
    labels=c("A", "B")
  )

  # Extract the legend from one of the plot is enough as it share legend
  # but the get_legend gives useless warning so suppress it
  leg <- suppressWarnings(
    cowplot::get_legend(
      memory_plot +
        labs(fill="Method action") +
        guides(
          fill = guide_legend(
            title.position = "left",
            label.position = "bottom",
            direction = "horizontal",
            nrow=1
          )
        )
    )
  )

  # Lastly combine both the main plot and the legend
  output_plot <- plot_grid(
    p_without_legend,
    leg,
    nrow=2,
    rel_heights = c(1, 0.1)
  )

  # Lastly save to file
  ggsave(
    filename=output_path |> here::here(),
    plot=output_plot,
    width=width,
    height=height,
    dpi=dpi,
    bg="white"
  )

  message("\nSaved figure computational resources into ", output_path)
}


# Lastly call the main function
# Read in parameters
opt <- docopt::docopt(doc)
input_path <- opt$input_path
output_path <- opt$output_path
text_size <- 12
width <- as.numeric(opt$width)
height <- as.numeric(opt$height)
dpi <- as.numeric(opt$dpi)
use_log <- FALSE

main(input_path=  input_path, output_path = output_path, text_size = text_size, width = width, height=height, dpi = dpi, use_log = use_log)
