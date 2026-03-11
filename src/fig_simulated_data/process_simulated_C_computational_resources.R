# ==============================================================================
# Simulated Data Computational Resources Analysis
# Description: Process Nextflow execution traces and dataset metadata to
#              summarize runtime and memory usage by method and action.
# ==============================================================================

# --- Libraries ----------------------------------------------------------------
suppressPackageStartupMessages({
  library(dplyr)
  library(stringr)
  library(tidyr)
})

# --- Custom sources -----------------------------------------------------------
source(here::here("src/common_helpers/computational_resources_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/retrieve_sim_params.R"))


# ==============================================================================
# 1. Process Nextflow execution trace
# ==============================================================================
# Read a Nextflow execution trace file and convert resource columns to numeric.

process_computational_trace <- function(trace_path = NULL) {
  if (is.null(trace_path)) {
    trace_path <- "data/raw/simulated_data/execution_trace.txt"
  }
  message("\n[process_computational_trace] Reading trace: ", trace_path)

  trace_df <- readr::read_tsv(trace_path, col_types = readr::cols()) %>%
    dplyr::select(process, tag, realtime, peak_rss, peak_vmem, duration) %>%
    mutate(process = chop_nf_core_prefix(process))

  message("[process_computational_trace] Splitting workflow and process names...")
  trace_df <- trace_df %>%
    separate_workflow_process(process) %>%
    mutate(process = case_when(
      workflow == "CROSS_VALIDATION" ~ str_extract(process, "[^:]+$"),
      workflow == "CALCULATE_METRICS" ~ "CALCULATE_METRICS",
      TRUE ~ process
    ))

  message("[process_computational_trace] Converting resource columns to numeric...")
  trace_df <- trace_df %>%
    mutate(
      realtime_sec = convert_to_seconds(realtime),
      duration_sec = convert_to_seconds(duration),
      peak_rss_mb  = convert_to_mb(peak_rss),
      peak_vmem_mb = convert_to_mb(peak_vmem)
    ) %>%
    dplyr::select(-c(realtime, peak_rss, duration, peak_vmem))


  return(trace_df)
}


# ==============================================================================
# 2. Process dataset metadata
# ==============================================================================
# Read dataset metadata and compute subject/feature/size summaries.
#

process_dataset_metadata <- function(metadata_path = NULL) {
  if (is.null(metadata_path)) {
    metadata_path <- "data/raw/simulated_data/dataset_metadata.csv"
  }
  message("\n[process_dataset_metadata] Reading metadata: ", metadata_path)

  metadata_df <- data.table::fread(metadata_path) %>%
    dplyr::select(dataset_name, feat_dimensions, subject_dimensions) %>%
    dplyr::mutate(
      dataset_name = str_remove(dataset_name, "_processed"),
      n_subjects   = as.integer(sub(",.*", "", subject_dimensions)),
      n_features   = sapply(
        strsplit(feat_dimensions, ","),
        function(x) sum(as.integer(x))
      )
    ) %>%
    dplyr::select(dataset_name, n_subjects, n_features) %>%
    mutate(dataset_size = n_subjects * n_features)

  message("[process_dataset_metadata] Loaded ", nrow(metadata_df), " datasets")
  return(metadata_df)
}


# ==============================================================================
# 3. Prepare plot-ready trace data
# ==============================================================================
# Filter and reshape the trace data for plotting.
#
# Keeps only CROSS_VALIDATION and FEATURE_SELECTION workflows, normalizes
# method/action names, and extracts dataset identifiers from tags.

prepare_plot_df <- function(trace_df, known_dname) {
  message("\n[prepare_plot_df] Filtering to CV and feature-selection workflows...")

  plot_df <- trace_df %>%
    filter(workflow %in% c("CROSS_VALIDATION", "FEATURE_SELECTION")) %>%
    filter(!str_detect(process, "MERGE"))

  message("[prepare_plot_df] Normalizing method and action names...")
  plot_df <- plot_df %>%
    mutate(process = case_when(
      str_detect(process, "COOPERATIVE") ~ str_replace(
        process, "COOPERATIVE_LEARNING", "MULTIVIEW"
      ),
      TRUE ~ process
    )) %>%
    mutate(
      method = str_replace(process, "_.*", ""),
      action = str_replace(process, ".*_", "")
    ) %>%
    filter(action != "DOWNSTREAM")

  message("[prepare_plot_df] Tagging null/full runs and extracting dataset names...")
  plot_df <- plot_df %>%
    mutate(process = case_when(
      str_detect(tag, "null") ~ str_c(process, "NULL", sep = "-"),
      str_detect(tag, "full") ~ str_c(process, "FULL", sep = "-"),
      TRUE ~ process
    )) %>%
    dplyr::select(
      workflow, process, tag, method, action,
      realtime_sec, peak_rss_mb, peak_vmem_mb, duration_sec
    ) %>%
    mutate(
      action       = str_replace(action, "FEATURE", "FEATURE_SELECT"),
      dataset_name = str_extract(tag, paste(known_dname, collapse = "|"))
    )

  return(plot_df)
}


# ==============================================================================
# 4. Summarize computational resources
# ==============================================================================
# Join metadata with trace data and compute per-method runtime summaries.
summarize_computational_resources <- function(metadata_df,
                                              plot_df,
                                              signals = c(0, 3, 100),
                                              output_path=NULL) {
  if (is.null(output_path)) {
    output_path <- "data/processed/simulated/simulated_panel_C_plot_data.rds"
  }

  message("\n[summarize_computational_resources] Joining metadata with trace data...")

  combined_df <- left_join(metadata_df, plot_df, by = "dataset_name") %>%
    filter(action != "PREPROCESS") %>%
    mutate(action = case_when(
      action %in% c("TRAIN", "PREDICT") ~ "model_assessment",
      action == "FEATURE_SELECT"         ~ "model_selection",
      TRUE ~ action
    )) %>%
    dplyr::rename(dataset = dataset_name) %>%
    retrieve_sim_params()

  message("[summarize_computational_resources] Normalizing method names...")
  combined_df <- combined_df %>%
    # This is specific handling to match the method colors label later
    mutate(method = case_when(
      method == "INTEGRAO"  ~ "IntegrAO",
      method == "MULTIVIEW" ~ "Multiview",
      method == "CARET"     ~ "caretMultimodal",
      TRUE ~ method
    )) %>%
    filter(signal %in% signals)

  message(
    "[summarize_computational_resources] Aggregating across ",
    n_distinct(combined_df$method), " methods and ",
    n_distinct(combined_df$action), " actions..."
  )

  # --- First pass: mean over datasets within each method/dataset/action -------
  per_dataset <- combined_df %>%
    dplyr::select(method, dataset, action, tag, realtime_sec, peak_rss_mb) %>%
    group_by(method, dataset, action) %>%
    summarize(
      realtime_sec = mean(realtime_sec),
      peak_rss_mb  = mean(peak_rss_mb),
      .groups = "drop"
    )

  # --- Second pass: median + sd across datasets per method/action -------------
  summary_wide <- per_dataset %>%
    group_by(method, action) %>%
    summarize(
      time     = median(realtime_sec),
      space    = median(peak_rss_mb),
      sd_time  = sd(realtime_sec),
      sd_space = sd(peak_rss_mb),
      .groups  = "drop"
    )

  # --- Pivot to long format, keep runtime only --------------------------------
  result <- summary_wide %>%
    pivot_longer(
      cols      = c(time, space),
      names_to  = "metric",
      values_to = "median_val"
    ) %>%
    filter(metric != "space") %>%
    mutate(metric = case_when(
      metric == "time" ~ "Runtime In Seconds",
      TRUE ~ NA_character_
    ))

  message("[summarize_computational_resources] Done. Rows: ", nrow(result))
  message("[summarize_computational_resources] Writing plot data to: ", output_path)
  saveRDS(result, output_path)
  return(result)
}


process_sim_panel_C_main <- function(
                  trace_path    = NULL,
                  metadata_path = NULL,
                  signals       = c(0, 3, 100),
                  output_path   = NULL) {

  message("\n=== Processing data for fig simulated panel C computational resources usage ===")

  # Step 1: Read and process trace
  raw_trace_df <- process_computational_trace(trace_path)

  # Step 2: Read and process metadata
  metadata_df <- process_dataset_metadata(metadata_path)
  known_dname <- metadata_df$dataset_name

  # Step 3: Further process trace data
  trace_df <- prepare_plot_df(raw_trace_df, known_dname)

  # Step 4: Summarize
  result <- summarize_computational_resources(metadata_df, trace_df, signals,
                                              output_path)

  return(result)
}

# ==============================================================================
# Lastly call it
process_sim_panel_C_main(
  trace_path=here::here("data/raw/simulated_data/execution_trace.txt"),
  metadata_path=here::here("data/raw/simulated_data/parsed_metadata.csv")
)
