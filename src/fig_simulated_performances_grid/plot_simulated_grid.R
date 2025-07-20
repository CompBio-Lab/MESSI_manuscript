doc <- "

This script is used to create figure of simulation data  of auc and feature selection performances
in grid like plot.

Usage:
  plot_simulated_grid.R [options]

Options:
  --input_path=INPUT      Path to load input data
  --output_path=OUTPUT    Path to write out plot
  --width=WIDTH           Width of the graph [default: 7]
  --height=height         Height of the graph [default: 7]
  --device=DEVICE         Device to print out [default: png]
  --dpi=DPI               Dots per inch [default: 300]
  --show_title=ST         Show plot title [default: 1]
"

# Parse doc
opt <- docopt::docopt(doc)

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)

# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))

# The plot function to use later
plot_line_point_grid <- function(plot_data) {
  output_plot <- plot_data |>
    ggplot(
      aes(
        x = method, y = value, color = corr,  group=corr)
    ) +
    geom_point(position = position_dodge(width = 0.4), size = 2) +
    geom_line(position = position_dodge(width = 0.4)) +
    facet_grid(metric~signal) +
    labs(y = "Performance Metric Value", x = "Method", color = "Correlation") +
    theme_bw(base_size = 14) +
    custom_theme_for_sim_plot() +
    scale_x_discrete(labels = function(x) stringr::str_wrap(x, width = 12)) +
    scale_color_manual(
      #values = c("0" = "#D55E00", "0.5" = "#0072B2", "1" = "#009E73"),
      values = c("0" = "#F4A6A6", "0.5" = "#A6DCEF", "1" = "#B9FBC0"),
      labels = c("0" = "Low", "0.5" = "Medium", "1" = "High")
    ) +
    theme(legend.position = "bottom") +
    guides(color = guide_legend(
      title.position = "top",
      label.position = "bottom",
      direction = "horizontal"
    ))

}


main <- function(input_path, output_path, width, height) {
  if (is.null(input_path)) {
    input_path <- "data/processed/simulation_performance_grid_df.csv" |>
      here::here()
  }

  if (is.null(output_path)) {
    output_path <- "results/figures/fig_simulated_performance_grid.png" |>
      here::here()
  }

  # First load plot data and apply factoring
  plot_data <- data.table::fread(input_path)


  # Then plot it as point and lines
  #output_plot <- plot_line_point_grid(plot_data)

  # Correct order should be: mofa-F1, mogonet- multiview?
  subset_for_order <- plot_data |>
    filter(signal == "3", metric == "sensitivity") |>
    group_by(method) |>
    summarize(mean_value = mean(value, na.rm = TRUE)) |>
    arrange(mean_value) |>
    dplyr::pull(method)


  output_plot <- plot_data |>
    dplyr::mutate(
      metric = as.factor(metric),
      signal = factor(signal, labels = c("Signal: Low", "Signal: Medium ", "Signal: High")),
      corr = as.factor(corr),
      method = factor(method, levels=subset_for_order)
    ) |>
    ggplot(
      aes(
        x = method, y = value, fill = corr,  group=corr)
    ) +
    geom_bar(stat="identity",  position = position_dodge2(padding=0.4)) +
    #geom_line(position = position_dodge(width = 0.4)) +
    facet_grid(metric~signal) +
    labs(y = "Performance Metric Value", x = "Method", fill = "Correlation") +
    theme_bw(base_size = 14) +
    custom_theme_for_sim_plot() +
    scale_x_discrete(labels = function(x) stringr::str_wrap(x, width = 12)) +
    scale_fill_manual(
      #values = c("0" = "#D55E00", "0.5" = "#0072B2", "1" = "#009E73"),
      #values = c("0" = "#F4A6A6", "0.5" = "#A6DCEF", "1" = "#B9FBC0"),
      #values = c("0" = "#E69F00", "0.5" = "#56B4E9", "1" = "#009E73"),
      #values = c("0" = "#E0BBE4", "0.5" = "#C084D3", "1" = "#6A51A3"),
      values = c("0" = "#C6DBEF", "0.5" = "#6BAED6", "1" = "#2171B5"),

      labels = c("0" = "Low", "0.5" = "Medium", "1" = "High")
    ) +
    theme(legend.position = "bottom") +
    guides(fill = guide_legend(
      title.position = "top",
      label.position = "bottom",
      direction = "horizontal"
    ))

  # Save the figure
  ggsave(
    filename = here::here(output_path),
    plot = output_plot,
    width = width,
    height = height
  )

  message("\nSaved simulation data grid plot into ", output_path)
}


opt <- docopt::docopt(doc)
main(input_path=opt$input_path, output_path=opt$output_path,
     width=as.numeric(opt$width),
     height=as.numeric(opt$height)
     )


