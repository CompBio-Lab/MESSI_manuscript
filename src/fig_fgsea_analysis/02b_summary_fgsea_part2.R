doc <- "

This script is used to get summary of fgsea part 1 results, which is then used in plot

Usage:
  02b_summary_fgsea_part2.R [options]

Options:
  --input_path=INPUT_PATH       File to load raw result of fgsea part 2
  --output_path=OUTPUT_PATH     File to output the summary table
  --cutoff=CUTOFF               P value cutoff to filter results
"



suppressPackageStartupMessages(library(dplyr))
library(tidyr)
library(stringr)

source(here::here("src/fig_fgsea_analysis/_utils.R"))


main <- function(input_path, output_path, cutoff) {
  if (is.null(input_path)) {
    input_path <- "data/processed/fgsea_part2_df.csv"
  }

  if (is.null(output_path)) {
    output_path <- "data/processed/fgsea_part2_summary_df.csv"
  }

  all_results <- data.table::fread(input_path)

  # First filter those that match organ of study with the organ of celltype
  filtered_results <- all_results %>%
    # Make everything lowercase first
    mutate(across(where(is.character), tolower)) %>%
    # Drop unwanted dataset early
    filter(!str_detect(dataset, "kipan")) %>%
    # Standardize dataset names before labeling
    #mutate(dataset = case_when(
    #  str_detect(dataset, "tcga") ~ str_replace(dataset, "-", "_"),
    #  TRUE ~ dataset
    #)) %>%
    # Apply manual labeling
    add_manual_label() %>%
    # Clean up method names
    mutate(
      method = method |>
        str_replace("-ncomp", "_ncomp") |>
        str_replace("-factor", "-Factor")
    ) %>%
    # Filter rows where organ matches label
    filter(str_detect(organ_label, organ)) %>%
    # Add columns in one mutate block
    group_by(method, dataset) %>%
    mutate(
      padj = p.adjust(pval, method="BH"),
      cell_type = pathway,
      method_dataset = paste(method, dataset, sep = "_")
    ) %>%
    ungroup()


  # Then make this wider data
  wide_n_sig_tab <- filtered_results %>%
    filter(!organ == "immune-system") %>%
    group_by(method, dataset, organ) %>%
    mutate(group_num = n()) %>%
    filter(padj < cutoff) %>%
    summarize(
      n = n(),
      group_num = unique(group_num),
      .groups = "drop"
    ) %>%
    ungroup() %>%
    mutate(ratio = n / group_num) %>%
    pivot_wider(names_from = organ, values_from = ratio, values_fill=0)

  # Lastly save this
  data.table::fwrite(wide_n_sig_tab, file=here::here(output_path))
  message("\nSaved fgsea part 2 summary into ", output_path)

}


opt <- docopt::docopt(doc)
main(input_path=opt$input_path, output_path=opt$output_path, cutoff=as.numeric(opt$cutoff))

