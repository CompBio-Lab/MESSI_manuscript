doc <- "

This script is used to make plot data for figure of computational time of simulated datasets.

Usage:
  clean_sim.R [options]

Options:
 --metadata=METADATA        Path to write out performance auc of real datasets
 --trace=TRACE              Path to write out performance auc of sim datasets
 --output_csv=OUTPUT_CSV    Path to write out computational time
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(purrr)
library(ggplot2)
library(stringr)
library(tidyr)

#source(here::here("src/common_helpers.R"))
source(here::here("src/common_helpers/retrieve_sim_params.R"))
source(here::here("src/fig_computational_time/_comp_time_utils.R"))

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

  plot_df <- merged_df %>%
    select(method, dataset, raw_seconds, action) %>%
    retrieve_sim_params()

  # Lastly write out to file
  write.csv(plot_df, file=output_path, row.names=FALSE)
}

# Parse cli
opt <- docopt::docopt(doc)

# Convenient vars
metadata_path <- opt$metadata
trace_path <- opt$trace
output_path <- opt$output_csv
# Execute the main function
main(metadata_path = metadata_path, trace_path = trace_path,
     output_path = output_path)

