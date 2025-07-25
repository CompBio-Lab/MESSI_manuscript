# Load libraries
source("src/fig_memory_time_usage/_utils.R")

library(ggplot2)

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
  select(workflow, process, tag, method, action, realtime_sec, peak_rss_mb)

p_time <- plot_df %>%
  select(-peak_rss_mb) %>%
  mutate(metric = "realtime_sec") %>%
  ggplot(aes(x=method, y=realtime_sec, fill=action)) +
  geom_boxplot() +
  scale_y_log10() +
  theme_bw() +
  ggh4x::facet_grid2(action ~ metric, scales = "free", independent = "all")

p_mem <- plot_df %>%
  select(-realtime_sec) %>%
  mutate(metric = "peak_rss_mb") %>%
  ggplot(aes(x=method, y=realtime_sec, fill=action)) +
  geom_boxplot() +
  scale_y_log10() +
  theme_bw() +
  ggh4x::facet_grid2(action ~ metric, scales = "free", independent = "all")


# Special function to plot it
plot_action_time <- function(df, action_val) {
  p <- df %>%
    filter(action == action_val) %>%
    ggplot(aes(x=reorder(process, realtime_sec), y=realtime_sec, fill = method)) +
    geom_boxplot() +
    theme_bw() +
    scale_y_log10() +
    coord_flip()
  return(p)
}



# First plot is for preprocess
#y_col <- "realtime_sec"
#y_col <- "duration_sec"

preprocess_time_plot <- plot_action_time(plot_df, "PREPROCESS")
train_time_plot <- plot_action_time(plot_df, "TRAIN")
predict_time_plot <- plot_action_time(plot_df, "PREDICT")
fs_time_plot <- plot_action_time(plot_df, "FEATURE")



library(cowplot)
time_top_row <- plot_grid(preprocess_time_plot + guides(fill = "none") + xlab(NULL),
                     fs_time_plot + guides(fill="none") + xlab(NULL))

time_bottom_row <- plot_grid(train_time_plot + guides(fill = "none") + xlab(NULL),
                        predict_time_plot + guides(fill = "none") + xlab(NULL))


plot_grid(time_top_row, time_bottom_row, nrow = 2)




# Special function to plot it
plot_action_mem <- function(df, action_val) {
  p <- df %>%
    filter(action == action_val) %>%
    ggplot(aes(x=reorder(process, peak_rss_mb), y=peak_rss_mb, fill = method)) +
    geom_boxplot() +
    theme_bw() +
    scale_y_log10() +
    coord_flip()
  return(p)
}



# First plot is for preprocess
#y_col <- "realtime_sec"
#y_col <- "duration_sec"

preprocess_plot <- plot_action_mem(plot_df, "PREPROCESS")
train_plot <- plot_action_mem(plot_df, "TRAIN")
predict_plot <- plot_action_mem(plot_df, "PREDICT")
fs_plot <- plot_action_mem(plot_df, "FEATURE")



library(cowplot)
top_row <- plot_grid(preprocess_plot + guides(fill = "none") + xlab(NULL),
                     fs_plot + guides(fill="none") + xlab(NULL))

bottom_row <- plot_grid(train_plot + guides(fill = "none") + xlab(NULL),
                        predict_plot + guides(fill = "none") + xlab(NULL))


plot_grid(top_row, bottom_row, nrow = 2)


