doc <- "

This script is used to make plot data for figure of computational time.

Usage:
  clean.R [options]

Options:
 --metadata=METADATA        Path to write out performance auc of real datasets
 --trace=TRACE              Path to write out performance auc of sim datasets
 --output_csv=OUTPUT_CSV    Path to write out computational time
 --data_type=DATA_TYPE      Type of data to processed. One of real, sim [default: real]
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(purrr)
library(ggplot2)
library(stringr)
library(tidyr)

source(here::here("src/common_helpers.R"))



# Custom functions ===============================================================
toSeconds <- function(x) {
  parts <- unlist(strsplit(x, " "))
  hours <- minutes <- seconds <- 0
  for (part in parts) {
    if (grepl("h", part)) {
      hours <- as.numeric(gsub("h", "", part))
    } else if (grepl("m", part)) {
      minutes <- as.numeric(gsub("m", "", part))
    } else if (grepl("s", part)) {
      seconds <- as.numeric(gsub("s", "", part))
    }

    # TODO: need to handle miliseconds as well?
  }
  return(hours * 3600 + minutes * 60 + seconds)
}


# Function to wrangle metadata
wrangle_metadata <- function(metadata_df) {
  metadata_df %>%
    rename(dataset = dataset_name) %>%
    # For the dataset names, remove the suffix _processed
    mutate(dataset = case_when(
      str_detect(dataset, "_processed") ~ str_remove(dataset, "_processed"),
      TRUE ~ dataset
    )) %>%
    mutate(subject_dimensions_list = str_split(subject_dimensions, ",")) %>%
    mutate(
      sample_size = map_dbl(
        subject_dimensions_list, ~ case_when(
          all(.x == .x[1]) ~ as.numeric(.x[1]),
          TRUE ~ NA
        )
      )
    ) %>%
    # Then remove these old columns after getting sample size
    select(-subject_dimensions_list, -subject_dimensions) %>%
    mutate(total_number_feature = str_split(feat_dimensions, ",") %>%
             map_dbl(~ sum(as.numeric(.x)))) %>%
    mutate(dataset_dim = sample_size * total_number_feature) %>%
    select(dataset, omics_names, sample_size,
           dataset_dim, is_simulated, positive_prop, feat_dimensions)
}



# ================================
# Function to wrangle trace
wrangle_trace <- function(
    trace_df,
    workflow_prefix="NFCORE_MESSI_BENCHMARK:MESSI_BENCHMARK:",
    time_col="duration") {

  trace_df_pre <- trace_df %>%
    select(process, tag, realtime, duration) %>%
    mutate(
      process = str_replace(process, workflow_prefix, "") |> tolower()
    ) %>%
    # Need to fix the cooperative learning name for regex matching later
    mutate(process = str_replace_all(process, "cooperative_learning", "multiview")) %>%
    # Get the ones of select feature and cross validation only
    # Since there are other jobs like prepare metadata
    filter(
      str_detect(process, "^feature_selection:[^_]+_select_feature") |
        str_detect(process, "^cross_validation:")
    ) %>%
    filter(
      !str_detect(process, "downstream|merge_result_table")
    ) %>%
    # Then just replace long prefixes in front of the process
    mutate(
      process = str_replace(
        process,
        "^(feature_selection:|cross_validation:cv.*:)", "")
    ) %>%
    # Now split the <method>_<action> to more columns
    separate(process, into = c("method", "action"), sep = "_", extra = "merge") %>%
    # Now for diablo, check if tag contains null or full (which is its design)
    mutate(
      method = case_when(
        str_detect(method, "diablo") & str_detect(tag, "-(null|full)") ~ paste0(
          method, str_extract(tag, "-(null|full)")
        ),
        str_detect(method, "mofa") ~ "mofa + glmnet",
        TRUE ~ method
      ),
      dataset = str_replace(tag, "-fold.*", ""),
      tag = str_replace(tag, "-(null|full)", "") # Clean up tag column
    ) %>%
    mutate(raw_seconds = sapply(!! sym( time_col ), toSeconds) |> as.numeric())
  # ============================================================================
  # Need to creat additional diablo rows given they shared same preprocess step
  diablo_null_copy <- trace_df_pre %>%
    filter(method == "diablo") %>%
    mutate(method = "diablo-null")

  diablo_full_copy <- trace_df_pre %>%
    filter(method == "diablo") %>%
    mutate(method = "diablo-full")

  # TODO: this might not be too readable?
  sgcca_copy <- trace_df_pre %>%
    filter(method == "rgcca",
           !str_detect(tag, "rgcca")) %>%
    mutate(method = "sgcca + lda") %>%
    distinct(tag, action, .keep_all=TRUE)


  # And also need to handle those of rgcca vs sgcca

  # Lastly combine these anad output it
  output_df <- trace_df_pre %>%
    # This remove the diablo "preprocess" step, and add in from our aside copy
    filter(method != "diablo", method != "rgcca") %>%
    bind_rows(diablo_null_copy, diablo_full_copy, sgcca_copy)

  return(output_df)
}

# ==================================================================================================================

main <- function(metadata_path, trace_path, output_path, data_type) {
  # First handle the metadata
  metadata_df <- read.csv(metadata_path) %>%
    as_tibble() %>%
    wrangle_metadata()


  # Then hanlde the execution trace
  # Then also want to wrangle the execution trace
  #trace_path <- "data/execution_trace.txt"
  trace_df <- readr::read_tsv(trace_path, col_types = readr::cols()) %>%
    wrangle_trace()
  # ================================================================
  # Now to combine the trace with the metadata
  merged_df <- left_join(
    x = metadata_df,
    y = trace_df,
    by = "dataset"
    ) %>%
    # Add a label column to group datasets by their sizes
    mutate(
      size_label = ifelse(
        dataset_dim < median(metadata_df$dataset_dim),
        "Small",
        "Large"
      )
    )

  if (data_type == "real") {
    plot_df <- merged_df %>%
      select(method, dataset, dataset_dim, size_label, raw_seconds, action)
  }

  if (data_type == "sim") {
    plot_df <- merged_df %>%
      select(method, dataset, raw_seconds, action) %>%
      retrieve_sim_params()
  }

  # Lastly write out to file
  write.csv(plot_df, file=output_path, row.names=FALSE)
}

# Parse cli
opt <- docopt::docopt(doc)

# Convenient vars
metadata_path <- opt$metadata
trace_path <- opt$trace
output_path <- opt$output_csv
data_type <- opt$data_type
# Execute the main function
main(metadata_path = metadata_path, trace_path = trace_path,
     output_path = output_path, data_type = data_type)

