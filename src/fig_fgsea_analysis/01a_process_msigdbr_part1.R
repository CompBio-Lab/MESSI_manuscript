doc <- "

This script is used to make plot data msigdbr fgsea

Usage:
  process_msigdbr_part1.R [options]

Options:
 --result_dir=DIR             Directory to read in fgsea top tables in rds
 --pathway_path=PATH          Path to the pathway database with collection names
 --output_path=OUTPUT_PATH    Path to write out output csv
"

opt <- docopt::docopt(doc)

source(here::here("src/fig_fgsea_analysis/_utils.R"))
# ===========================================
# Use this script to process the result after running fgsea by looking
# at msigdbr C2 reactome and C6
# ===========================================
library(purrr)
library(dplyr)
library(stringr)
# Important variables


result_dir <- opt$result_dir
msigdr_pathways_path <- opt$pathway_path
output_path <- opt$output_path


# Main entrance of the script
main <- function(result_dir, msigdr_pathways_path,
                 output_path="fgsea_part1_df.csv") {

  if (is.null(result_dir)) {
    result_dir <- "data/raw/fgsea_results/fgsea_part1/"

  }

  if (is.null(msigdr_pathways_path)) {
    msigdbr_pathways_path <- "data/processed/msigdbr_pathways_collection.rds"
  }

  if (is.null(output_path)) {
    output_path <- "data/processed/fgsea_part1_df.csv"
  }
  dataset_prefixes <- c("tcga", "GSE", "rosmap")
  # For all files here lets merge it
  rds_files <- list.files(
    here::here(result_dir),
    full.names = TRUE
  )

  # Read and combine all results
  all_results <- map_dfr(rds_files, read_and_annotate)
  # Now also load the pathways and combine it together
  msigdbr_pathways <- readRDS(msigdbr_pathways_path)
  # ===================
  # Now combine the pathways collection name into one df
  fgsea_results_part1_df <- inner_join(
    all_results, msigdbr_pathways,
    by = c("pathway" = "gs_name")
  ) %>%
    # Then in this one, need to readjust the pval later, so
    # rename its existing padj to another name
    dplyr::rename(old_padj = padj) %>%
    dplyr::select(-c("gs_collection")) %>%
    tidyr::separate_wider_delim(
      comb_name, delim = " | ",
      names = c("method", "dataset", "view"),
      too_many = "merge", too_few = "align_start"
    ) %>%
    group_by(method, dataset, view) %>%
    mutate(padj = p.adjust(pval))
  # Lastly write it to file
  data.table::fwrite(fgsea_results_part1_df, file=output_path)
}

# Execute it
main(result_dir=result_dir,
     msigdr_pathways_path=msigdr_pathways_path, output_path=output_path)




