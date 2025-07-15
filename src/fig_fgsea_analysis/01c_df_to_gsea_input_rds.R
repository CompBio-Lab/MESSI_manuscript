# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(tidyr)
#library(msigdbr)
#source(here::here("src/common_helpers.R"))

#
# # Load the pathways
# reactome_pathways <- msigdbr(species = "Homo sapiens", collection = "C2", subcollection = "CP:REACTOME")
# oncogenic_pathways <- msigdbr(species = "Homo sapiens", collection = "C6")
#
# # Select relevant columns
# relevant_cols <- c("gene_symbol", "gs_name", "gs_collection",
#                    "gs_collection_name")
#
# pathways_df <- bind_rows(reactome_pathways, oncogenic_pathways) |>
#   # And filter those of human only
#   dplyr::filter(gs_source_species == "HS") %>%
#   dplyr::select(all_of(relevant_cols)) %>%
#   as_tibble()
#
# pathways_list <- pathways_df %>%
#   group_by(gs_name) |>
#   summarize(gene_list = list(gene_symbol)) %>%
#   mutate(gene_list = map(gene_list, unlist)) %>%
#   deframe()



# Load the data with symbols
input_path <- "data/processed/feat_selection_symbols.csv"
feat_df <- data.table::fread(input_path)

gsea_input_list <- feat_df %>%
  mutate(stat = abs(coef)) %>%
  arrange(desc(stat)) %>%
  mutate(group = paste(method, dataset, view, sep = " | ")) %>%
  group_by(group) %>%
  summarise(stat_vec = list(setNames(stat, symbol)), .groups = "drop") %>%
  deframe()

gsea_input_list |> names() |> sample(10)


batch_size <- 10
n_batches <- ceiling(length(gsea_input_list) / batch_size)

# Generate batch indices
split_indices <- ceiling(seq_along(gsea_input_list) / batch_size)

# Split list into batches while keeping names and internal vector names
batched_input <- split(gsea_input_list, split_indices)
# names(batched_input)

for (i in seq_len(length(batched_input))) {
  saveRDS(batched_input[[i]],
          file = paste0("batched_input-", i, ".rds"))
}



