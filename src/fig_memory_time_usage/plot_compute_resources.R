# Load libraries
library(ggplot2)
library(forcats)
library(dplyr)
library(cowplot)


# Load custom scripts
source("src/fig_memory_time_usage/_utils.R")
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

trace_path <- "data/raw/real_data_results/execution_trace.txt"

# Read the trace in
trace_df <- readr::read_tsv(trace_path,
                            col_types = readr::cols()) |>
  select(process,tag,realtime, peak_rss,peak_vmem, duration) |>
  mutate(process = chop_nf_core_prefix(process)) %>%
  separate_workflow_process(process) %>%
  mutate(
    realtime_sec = convert_to_seconds(realtime),
    duration_sec = convert_to_seconds(duration),
    peak_rss_mb = convert_to_mb(peak_rss),
    peak_vmem_mb = convert_to_mb(peak_vmem)
  ) %>%
  select(-c("realtime", "peak_rss", "duration", "peak_vmem")) %>%
  mutate(process = case_when(
    # If the workflow is from cv do something special
    workflow == "CROSS_VALIDATION" ~ str_extract(process, "[^:]+$"),
    workflow == "CALCULATE_METRICS" ~ "CALCULATE_METRICS",
    TRUE ~ process
  ))

wrangle_df <- trace_df %>%
  filter(workflow %in%  c("CROSS_VALIDATION", "FEATURE_SELECTION")) %>%
  filter(!str_detect(process, "MERGE")) %>%
  # Change the label of multiview
  mutate(process = case_when(
    str_detect(process, "COOPERATIVE") ~ str_replace(
      process, "COOPERATIVE_LEARNING", "MULTIVIEW"
    ),
    TRUE ~ process
  )) %>%
  # Create a plot identifier for each workflow
  mutate(method = str_replace(process, "_.*", ""),
         action = str_replace(process, ".*_", "")) %>%
  filter(action != "DOWNSTREAM") %>%
  mutate(process = case_when(
    str_detect(tag, "null") ~ str_c(process, "NULL", sep="-"),
    str_detect(tag, "full") ~ str_c(process, "FULL", sep="-"),
    TRUE ~ process
  ))

plot_df <- wrangle_df %>%
  select(workflow, process, tag, method, action, realtime_sec, peak_vmem_mb, duration_sec)  %>%
  # Change values for FEATURE
  mutate(action=str_replace(action, "FEATURE", "FEATURE_SELECT")) %>%
  mutate(
    # Let action to have fixed levels
    action = factor(action, levels = c("PREPROCESS", "TRAIN", "PREDICT", "FEATURE_SELECT"))
  )

plot_metric <- function(data, metric_col, metric_label, y_lab, text_size, alpha=0.5, use_log=FALSE) {

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


text_size <- 12
use_log <- TRUE
a_plot <- plot_metric(plot_df, "duration_sec", "Duration", y_lab = "Duration (seconds)", text_size=text_size, use_log=use_log)
b_plot <- plot_metric(plot_df, "peak_vmem_mb", "Memory", y_lab = "RAM memory usage (MB)", text_size=text_size, use_log=use_log)

p_without_legend <- plot_grid(
  a_plot + theme(legend.position = "none",
                 strip.text.y = element_blank()),
  b_plot + theme(legend.position = "none"),
  ncol=2,
  labels=c("A", "B")
)

leg <- cowplot::get_legend(
  b_plot +
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

output_plot <- plot_grid(
  p_without_legend,
  leg,
  nrow=2,
  rel_heights = c(1, 0.1)
)

# Series of params to cli
output_path <- "results/figures/fig_computation_resources.png" |> here::here()
width <- 12
height <- 9
dpi <- 700

# Lastly save to file
ggsave(
  filename=output_path,
  plot=output_plot,
  width=width,
  height=height,
  dpi=dpi,
  bg="white"
  )


