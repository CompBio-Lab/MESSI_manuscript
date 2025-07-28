doc <- "

This script is used to make plot data for figure computational resources usage for real data.

Usage:
  clean.R [options]

Options:
  --input_path=INPUT_PATH       Path to read in the trace file
  --output_path=OUTPUT          Path to write out plot data
"

# Load library
suppressPackageStartupMessages(library(dplyr))

# Load utils
source("src/fig_computational_resources_usage/_utils.R")



main <- function(input_path, output_path) {
  if (is.null(input_path)) {
    input_path <- "data/raw/real_data_results/execution_trace.txt"
  }

  if (is.null(output_path)) {
    output_path <- "data/processed/computational_resources_usage_df.csv"
  }
  # Read the trace in
  trace_df <- readr::read_tsv(
    input_path,
    col_types = readr::cols()
  ) |>
    # Get relevant cols
    select(process,tag,realtime, peak_rss,peak_vmem, duration) |>
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
    select(-c("realtime", "peak_rss", "duration", "peak_vmem"))

  # Wrangle it further to plot ready data

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
    select(workflow, process, tag, method, action, realtime_sec, peak_rss_mb, peak_vmem_mb, duration_sec)  %>%
    # Change values for FEATURE
    mutate(action=str_replace(action, "FEATURE", "FEATURE_SELECT"))

  # Lastly write to file
  data.table::fwrite(plot_df, file=output_path |> here::here(), row.names = FALSE)


  message("\nSaved plot data of fig computational resource usages into ", output_path)
}

# Call the fun here
opt <- docopt::docopt(doc)
input_path <- opt$input_path
output_path <- opt$output_path
main(input_path=input_path, output_path=output_path)

