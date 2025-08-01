doc <- "

This script is used to get summary of fgsea part 1 results, which is then used in plot

Usage:
  02a_summary_fgsea_part1.R [options]

Options:
  --input_path=INPUT_PATH       File to load raw result of fgsea part 1
  --output_path=OUTPUT_PATH     File to output the summary table
  --cutoff=CUTOFF               P value cutoff to filter results
"

suppressPackageStartupMessages(library(dplyr))


source("src/common_helpers/standardize_data_funs.R")

main <- function(input_path, output_path, cutoff) {
  if (is.null(input_path)) {
    input_path <- "data/processed/fgsea_part1_df.csv"
  }
  if (is.null(output_path)) {
    output_path <- "data/processed/fgsea_part1_summary_df.csv"
  }

  all_results <- data.table::fread(here::here(input_path))

  #all_results

  combined_summary <- all_results %>%
    filter(padj < cutoff) %>%
    # TODO: move this fix to somewhere else
    dplyr::mutate(
      method = stringr::str_replace(method, "-ncomp", "_ncomp")
    ) %>%
    # Capitalize or to upper the method names
    mutate(method = standardize_method_names(method)) %>%
    #group_by(method, dataset, view, gs_collection_name) %>%
    group_by(method, dataset, gs_collection_name) %>%
    summarize(n_sig = n(), .groups = "drop") %>%
    group_by(method, gs_collection_name) %>%
    summarize(mean_n_sig = mean(n_sig),
              sd_n_sig = sd(n_sig),
              .groups = "drop")

  data.table::fwrite(combined_summary, file=here::here(output_path))
  message("\nSaved fgsea part 1 summary into ", output_path)
}

opt <- docopt::docopt(doc)
main(input_path=opt$input_path, output_path=opt$output_path, cutoff=as.numeric(opt$cutoff))

