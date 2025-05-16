# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(stringr)
library(tidyr)

source(here::here("src/common_helpers.R"))

# Load the pathways
reactome_pathways <- msigdbr(species = "Homo sapiens", collection = "C2", subcollection = "CP:REACTOME")
oncogenic_pathways <- msigdbr(species = "Homo sapiens", collection = "C6")

# Select relevant columns
relevant_cols <- c("gene_symbol", "gs_name", "gs_collection",
                   "gs_collection_name")

pathways_df <- bind_rows(reactome_pathways, oncogenic_pathways) |>
  # And filter those of human only
  dplyr::filter(gs_source_species == "HS") %>%
  dplyr::select(all_of(relevant_cols)) %>%
  as_tibble()

pathways_list <- pathways_df %>%
  group_by(gs_name) |>
  summarize(gene_list = list(gene_symbol)) %>%
  mutate(gene_list = map(gene_list, unlist)) %>%
  deframe()



# Load the data with symbols
feat_df <- data.table::fread("data/processed/feat_selection_symbols.csv")

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

names(batched_input)

for (i in seq_len(length(batched_input))) {
  saveRDS(batched_input[[i]], file = paste0("batched_input-", i, ".rds"))
}


# batched_input[[1]]
#
#
# # For each item its a stats vector
# batch_names <- batched_input[[1]] |> names()

# run_fgsea_single <- function(ranks, pathways, minSize, maxSize, eps) {
#   fgsea::fgsea(pathways = pathways, stats = ranks, minSize = minSize, maxSize, eps=eps)
# }
#
# set.seed(1)
#
# first_batch_res <- lapply(batch_names, function(comb_name) {
#   ranks <- batched_input[[1]][[comb_name]]
#   noise <- rnorm(n=length(ranks), sd=0.001)
#   result <- run_fgsea_single(
#     ranks = ranks + noise,
#     pathways = pathways_list,
#     minSize = 5, maxSize = 10000, eps = 0)
#   # Add the combination name into it
#   result$comb_name <- comb_name
#   return(result)
# })

# batch_names[1] |> utf8ToInt() |> sum()
#
# names(first_batch_res)
#
#
# names(first_batch_res) <- batch_names
#
# aaa <- first_batch_res$`diablo-full-ncomp-1 | GSE38609 | mrna` |> as_tibble()
#
# new_batch <- lapply(first_batch_res)
# f1
# nnn <- names(first_batch_res)
# f1 <- nnn[2]
# first_batch_res[[f1]]
#
# klk <- lapply(names(first_batch_res), function(comb_name) {
#   result <- first_batch_res[[comb_name]]
#   result$comb_name <- comb_name
#   return(result)
# })
#
# names(klk) <- names(first_batch_res)
#
# df <- data.frame()
#
# df
# comb_name <- "hello world"
# message(comb_name, " has 0 rows in fgsea table, skipping")
#
# nrow(df) == 0
#
# irst_batch_res |> lapply(dim)
#
#
# aas <- dplyr::bind_rows(first_batch_res)
# aad <- do.call(rbind, first_batch_res)
#
# aad |>
#   as_tibble()
#
# aaa |>
#   dplyr::select(pathway, padj, log2err, NES) |>
#   dplyr::filter(padj < 0.2)


