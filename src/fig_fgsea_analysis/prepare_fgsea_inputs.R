doc <- "

This script is used to wrap cleaned feature selection result with symbols into list entries
for GSEA analysis, note here each output is batched version, where each batch could contain multiple stat vectors

Usage:
  prepare_fgsea_inputs.R [options]

Options:
  --input_path=INPUT_PATH       File to load the input of feat selection results with symbols
  --output_dir=OUTPUT_DIR       Directory to output the batched rds
  --batch_size=BATCH_SIZE       Size of each batch [default: 10]
"


# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(tidyr)


# Load the data with symbols
main <- function(input_path, output_dir, batch_size) {
  if (is.null(input_path)) {
    input_path <- "data/processed/feat_selection_symbols.csv"
  }

  if (is.null(output_dir)) {
    output_dir <- "data/batched_input_for_fgsea"
  }

  feat_df <- data.table::fread(here::here(input_path))

  gsea_input_list <- feat_df %>%
    mutate(stat = abs(coef)) %>%
    arrange(desc(stat)) %>%
    mutate(group = paste(method, dataset, view, sep = " | ")) %>%
    group_by(group) %>%
    summarise(stat_vec = list(setNames(stat, symbol)), .groups = "drop") %>%
    tibble::deframe()

  #gsea_input_list |> names() |> sample(10)

  # Then batch the input list together to be run together
  n_batches <- ceiling(length(gsea_input_list) / batch_size)

  # Generate batch indices
  split_indices <- ceiling(seq_along(gsea_input_list) / batch_size)

  # Split list into batches while keeping names and internal vector names
  batched_input <- split(gsea_input_list, split_indices)
  # names(batched_input)

  dir.create(here::here(output_dir), recursive = TRUE, showWarnings = FALSE)
  for (i in seq_len(length(batched_input))) {
    output_path <- here::here(output_dir, paste0("batched_input-", i, ".rds"))
    saveRDS(batched_input[[i]],
            file = output_path)
  }
  message("\nSaved batched input stat list for gsea into ", output_dir)
}

# Lastly call the main function
opt <- docopt::docopt(doc)
main(input_path=opt$input_path, output_dir=opt$output_dir,
     batch_size=as.numeric(opt$batch_size))




