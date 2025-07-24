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
library(patchwork)

# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))


# Use this function to create the individual panel
create_panel_plot <- function(data, metric_filter, metric_label, y_label_expr, text_size) {
  data |>
    filter(metric == metric_filter) |>
    mutate(metric = metric_label) |>
    ggplot(aes(x = method, y = value, fill = corr)) +
    geom_bar(stat = "identity", position = position_dodge2(padding = 0.4)) +
    ylab(y_label_expr) +
    theme_bw(base_size = text_size) +
    facet_grid(metric ~ signal) +
    # Calls on another theme in plot_utils
    custom_theme_for_sim_plot() +
    scale_x_discrete(labels = function(x) stringr::str_wrap(x, width = 12)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.07))) +
    scale_fill_manual(
      values = c("0" = "#C6DBEF", "0.5" = "#6BAED6", "1" = "#2171B5"),
      labels = c("0" = "Low", "0.5" = "Medium", "1" = "High")
    ) +
    labs(fill="Correlation") +
    guides(
      fill = guide_legend(
        title.position = "left",
        label.position = "bottom",
        direction = "horizontal"
      )
    ) +
    # This is remove extra space after final arrangement
    theme(plot.margin = margin(6, 0, 0, 6))
}



# Additional theme to empty legend and ticks
theme_empty_legend_ticks <- function() {
  theme(
    legend.position="none",
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.title.x = element_blank(),
  )
}

# Additional theme to remove the ribbon text from grid.x
theme_empty_ribbon <- function() {
  theme(
    strip.background.x = element_blank(),
    strip.text.x = element_blank()
  )
}

# The plot function to use later (deprecated)
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


main <- function(input_path, output_path, width, height, text_size) {
  if (is.null(input_path)) {
    input_path <- "data/processed/simulation_performance_grid_df.csv" |>
      here::here()
  }

  if (is.null(output_path)) {
    output_path <- "results/figures/fig_simulated_performance_grid.png" |>
      here::here()
  }

  # First load plot data and apply factoring
  input_data <- data.table::fread(input_path)
  # Correct order should be: mofa-F1, mogonet- multiview?
  method_order <- input_data |>
    filter(signal == "3", metric == "sensitivity") |>
    group_by(method) |>
    summarize(mean_value = mean(value, na.rm = TRUE)) |>
    arrange(mean_value) |>
    dplyr::pull(method)


  plot_data <- input_data |>
    dplyr::mutate(
      metric = as.factor(metric),
      signal = factor(signal, labels = c("Signal: Low", "Signal: Medium ", "Signal: High")),
      corr = as.factor(corr),
      method = factor(method, levels=method_order)
    )



  # Old label expr -> expression("Proportion of " * frac(TP^"*", TP^"*" + FN^"*")
  # expression("Proportion of " * TP^"*" / (TP^"*" + FN^"*"))

  # First create the independent panels
  auc_panel <- create_panel_plot(
    data = plot_data,
    metric_filter = "auc",
    metric_label = "AUC",
    y_label_expr = "Mean AUC of 5-fold CV",
    text_size = text_size
  )


  sensitivity_panel <- create_panel_plot(
    data = plot_data,
    metric_filter = "sensitivity",
    metric_label = "Signal Variables",
    #y_label_expr = expression("Proportion of TP^* / TP^* + FN^*")
    #y_label_expr = expression("Proportion of " * TP^"*" / (TP^"*" + FN^"*"))
    y_label_expr = "Proportion of variables selected",
    text_size = text_size
  )

  specificity_panel <- create_panel_plot(
    data = plot_data,
    metric_filter = "specificity",
    metric_label = "Noise Variables",
    #y_label_expr = "Proportion of TN^* / TN^* + FP^*"
    #y_label_expr = expression("Proportion of " * TN^"*" / (TN^"*" + FP^"*"))
    y_label_expr = "Proportion of variables selected",
    text_size
  )


  # ==========================================================
  # Merging the panels together
  # First make the bottom row with patchwork
  # Using cowplot is extremely due to alignment problems
  bottom_row <- (sensitivity_panel + theme_empty_legend_ticks()) /
    (specificity_panel +
    xlab(NULL))+
    plot_layout(axes = "collect")


  # This is empty space ratio
  panel_space <- 0.025
  # Now stack top and bottom rows
  output_plot <- cowplot::plot_grid(
    auc_panel + theme_empty_legend_ticks(),
    NULL, # spacer
    bottom_row,
    nrow = 3,
    rel_heights = c(0.3, panel_space, 0.8),
    align="v",
    axis="lr",
    labels = c("A", "", "B"),
    label_size=text_size
  )


  # Save the figure
  # The bg white is must, otherwise fig would look weird
  ggsave(
    filename = here::here(output_path),
    plot = output_plot,
    width = width,
    height = height,
    bg="white"
  )

  message("\nSaved simulation data grid plot into ", output_path)
}


opt <- docopt::docopt(doc)


# TODO: move this to CLI later
text_size <- 16
main(input_path=opt$input_path, output_path=opt$output_path,
     width=as.numeric(opt$width),
     height=as.numeric(opt$height),
     text_size=as.numeric(text_size)
     )


