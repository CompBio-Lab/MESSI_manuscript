# Read the trace in
trace_df <- readr::read_tsv("data/raw/real_data_results/execution_trace.txt") |>
  select(process,tag,realtime, peak_rss,peak_vmem, duration) |>
  # Chop the long prefix
  mutate(process = str_replace(
    process,"NFCORE_MESSI_BENCHMARK:MESSI_BENCHMARK:", "")
    ) |>
  # Group the workflow
  tidyr::separate_wider_delim(
    process, delim=":", names=c("workflow", "process"),
    too_many="merge", too_few="align_start") %>%
  mutate(process = case_when(
    # If the workflow is from cv do something special
    workflow == "CROSS_VALIDATION" ~ str_extract(process, "[^:]+$"),
    workflow == "CALCULATE_METRICS" ~ "CALCULATE_METRICS",
    TRUE ~ process
  ))

trace_df$realtime %>% sample(6)


convert_to_seconds <- function(time_str) {
  # Hours (digits before 'h')
  hours <- str_extract(time_str, "\\d+(?=h)") %>% as.numeric()

  # Minutes (digits before 'm' but NOT followed by 's')
  minutes <- str_extract(time_str, "\\d+(?=m(?!s))") %>% as.numeric()

  # Seconds (digits with optional decimals before 's' but NOT preceded by 'm')
  seconds <- str_extract(time_str, "\\d+(\\.\\d+)?(?=s)") %>% as.numeric()

  # Milliseconds (digits with optional decimals before 'ms')
  milliseconds <- str_extract(time_str, "\\d+(\\.\\d+)?(?=ms)") %>% as.numeric()

  # Replace NAs with 0
  hours[is.na(hours)] <- 0
  minutes[is.na(minutes)] <- 0
  seconds[is.na(seconds)] <- 0
  milliseconds[is.na(milliseconds)] <- 0

  # Calculate total seconds
  total_seconds <- hours * 3600 + minutes * 60 + seconds + milliseconds / 1000
  return(total_seconds)
}


convert_to_mb <- function(x) {
  # Extract numeric value and unit
  value <- as.numeric(stringr::str_extract(x, "[0-9.]+"))
  unit <- stringr::str_extract(x, "[KMG]B")

  # Conversion based on unit
  multiplier <- dplyr::case_when(
    unit == "KB" ~ 1 / 1024,
    unit == "MB" ~ 1,
    unit == "GB" ~ 1024,
    TRUE ~ NA_real_  # For unknown units
  )

  # Convert to MB
  value * multiplier
}


plot_df <- trace_df %>%
  mutate(realtime_sec = convert_to_seconds(realtime),
         duration_sec = convert_to_seconds(duration)) %>%
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
  )) %>%
  mutate(peak_rss_mb = convert_to_mb(peak_rss))




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


