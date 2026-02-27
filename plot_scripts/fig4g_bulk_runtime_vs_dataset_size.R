# Load custom scripts
source("plot_scripts/computational_resources_utils.R")


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

# Load library
suppressPackageStartupMessages(library(dplyr))

# Load utils
trace_path <- "data/raw/bulk_data/execution_trace.txt"
# Read the trace in
trace_df <- readr::read_tsv(
  trace_path,
  col_types = readr::cols()
) |>
  # Get relevant cols
  dplyr::select(process,tag,realtime, peak_rss,peak_vmem, duration) |>
  mutate(process = chop_nf_core_prefix(process)) %>%
  # This takes long names from process to further apart as workflow and process
  separate_workflow_process(process) %>%
  # Further normalize the process after splitting names in it
  mutate(process = case_when(
    # If the workflow is from cv do something special
    workflow == "CROSS_VALIDATION" ~ str_extract(process, "[^:]+$"),
    # Add missing "label" for metrics
    workflow == "CALCULATE_METRICS" ~ "CALCULATE_METRICS",
    # Rest remain same
    TRUE ~ process
  )) %>%
  # Important step convert the strings to numeric values for metric cols
  mutate(
    realtime_sec = convert_to_seconds(realtime),
    duration_sec = convert_to_seconds(duration),
    peak_rss_mb = convert_to_mb(peak_rss),
    peak_vmem_mb = convert_to_mb(peak_vmem)
  ) %>%
  # And remove those redundant ones
  dplyr::select(-c("realtime", "peak_rss", "duration", "peak_vmem"))


# Also load dataset stuff
metadata_path <- "data/raw/bulk_data/parsed_metadata.csv"
metadata_df <- data.table::fread(metadata_path) |>
  dplyr::select(dataset_name, feat_dimensions, subject_dimensions) |>
  dplyr::mutate(
    dataset_name = str_remove(dataset_name, "_processed"),
    n_subjects = as.integer(sub(",.*", "", subject_dimensions)),  # take first value
    n_features = sapply(strsplit(feat_dimensions, ","),
                        function(x) sum(as.integer(x)))
  ) %>%
  dplyr::select(dataset_name, n_subjects, n_features)  %>%
  mutate(dataset_size = n_subjects * n_features)

known_dname <- metadata_df$dataset_name


plot_df  <- trace_df %>%
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
  dplyr::select(workflow, process, tag, method, action, realtime_sec, peak_rss_mb, peak_vmem_mb, duration_sec)  %>%
  # Change values for FEATURE
  mutate(
    action=str_replace(action, "FEATURE", "FEATURE_SELECT"),
    dataset_name=str_extract(tag, paste(known_dname, collapse = "|"))
  )


# Now combine both info
combined_df <- left_join(
  metadata_df, plot_df, by="dataset_name"
) |>
  # And drop chol, kipan
  filter(!dataset_name %in% c("tcga-chol", "tcga-kipan"))

# combined_df |>
#   summarise(
#     median = median(realtime_sec),
#     q25 = quantile(realtime_sec, 0.25),
#     q75 = quantile(realtime_sec, 0.75),
#     .by = c(dataset_name, dataset_size, method)
#   ) |>
#   ggplot(aes(x = dataset_size, color = method, fill = method, group = method)) +
#   geom_ribbon(aes(ymin = q25, ymax = q75), alpha = 0.15, color = NA) +
#   geom_line(aes(y = median)) +
#   geom_point(aes(y = median), size = 2) +
#   scale_x_log10() + scale_y_log10() +
#   theme_bw()
#
#
# filter(action != "PREPROCESS") %>%
#   mutate(
#     action = case_when(
#       action %in% c("TRAIN", "PREDICT") ~ "model_assessment",
#       action == "FEATURE_SELECT" ~ "model_selection",
#       TRUE ~ action
#     )
#   ) %>%
#   # CHECK HERE
#   group_by(method, dataset_name, action, tag) %>%
#   mutate(
#     realtime_sec = sum(realtime_sec)
#   ) %>%
#   ungroup() %>%
#   summarise(
#     across(c(realtime_sec, peak_rss_mb), median),
#     .by = c(dataset_name, dataset_size, method, action)
#   ) %>%
#   ggplot(aes(x = dataset_size, y = realtime_sec, color = method)) +
#   geom_line(aes(group = method)) +
#   geom_point(size = 1.5) +
#   facet_wrap(~ action, scales = "free_y") +
#   scale_x_log10(labels = scales::label_comma()) +
#   scale_y_log10() +
#   labs(x = "Dataset Size", y = "Median Runtime (sec)") +
#   theme_bw()
# #

out_plot <- combined_df |>
  summarise(
    across(c(realtime_sec, peak_rss_mb), median),
    .by = c(dataset_name, dataset_size, method, action)
  ) |>
  ggplot(aes(x = dataset_size, y = realtime_sec, color = method)) +
  geom_line(aes(group = method)) +
  geom_point(size = 1.5) +
  facet_wrap(~ action, scales = "free_y") +
  scale_x_log10(labels = scales::label_comma()) +
  scale_y_log10() +
  labs(x = "Dataset Size", y = "Median Runtime (sec)") +
  theme_bw()

output_png_path <- "fig4g_bulk_runtime_vs_dataset_size.png"

ggsave(output_png_path, out_plot, width = 12, height=8)
message("\nDone fig4g bulk time complexity plot, see fig at", output_png_path)
