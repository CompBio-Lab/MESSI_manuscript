# Load library
library(dplyr)
# Load fun
source("src/common_helpers/standardize_data_funs.R")

df <- data.table::fread("data/raw/multimodal_data/all_feature_selection_results.csv") %>%
  standardize_view_names() %>%
  mutate(method=standardize_method_names(method)) %>%
  #standardize_method_names2() %>%
  # Rename column
  dplyr::rename(dataset = dataset_name) %>%
  # Drop dataset_type and feature_type
  dplyr::select(-dataset_type, -feature_type)

# Only these views have actual symbol that could be enriched
symbolic_views <- c("proteins", "mrna", "rna", "cna")

multimodal_gsea_input_list <- df %>%
  # Only these ones have symbols and could run enrichment
  filter(view %in% symbolic_views) %>%
  #mutate(stat = abs(coef)) %>%
  arrange(desc(coef)) %>%
  mutate(group = paste(method, dataset, view, sep = " | ")) %>%
  group_by(group) %>%
  summarise(stat_vec = list(setNames(coef, feat)), .groups = "drop") %>%
  tibble::deframe()

output_name <- "data/processed/multimodal/multimodal_fgsea_list_input.rds"
if (!dir.exists(dirname(output_name))) dir.create(dirname(output_name), recursive = T)
saveRDS(multimodal_gsea_input_list, output_name)
message("\nSaved multimodal data gsea input to: ",output_name)

