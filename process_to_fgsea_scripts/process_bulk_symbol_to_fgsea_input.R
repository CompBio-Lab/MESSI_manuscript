library(dplyr)

main <- function(input_path, output_path) {
  if (is.null(input_path)) {
    input_path <- "data/processed/feat_selection_symbols.csv"
  }

  if (is.null(output_path)) {
    output_path <- "data/processed/fgsea_input_list.rds"
  }

  feat_df <- data.table::fread(here::here(input_path))
  # Use absolute values for methods that could have flipped signs
  #abs_strings <- c("mofa", "integrao", "mogonet")
  gsea_input_list <- feat_df %>%
    mutate(stat = abs(coef)) %>%
    arrange(desc(stat)) %>%
    mutate(group = paste(method, dataset, view, sep = " | ")) %>%
    group_by(group) %>%
    summarise(stat_vec = list(setNames(stat, symbol)), .groups = "drop") %>%
    tibble::deframe()
  # Save it to file
  saveRDS(gsea_input_list, output_path)
  message("Saved to ", output_path)
  return(gsea_input_list)
}

# Run it
input_path <- "data/processed/bulk/feat_selection_symbols.csv"
output_path <- "data/processed/bulk/bulk_fgsea_list_input.rds"
fgsea_input_list <-main(input_path=input_path, output_path=output_path)
