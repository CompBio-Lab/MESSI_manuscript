
library(dplyr)
library(ggplot2)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))



df <- data.table::fread("data/processed/multimodal/multimodal_msigdbr_fgsea.csv")
msigdbr_pathways <- readRDS("data/processed/pathways_db/msigdbr_pathways_collection.rds")


# For the multimodal datasets should look at reactome pathways only
multimodal_msigdbr_df <- inner_join(
  df, msigdbr_pathways,
  by = c("pathway" = "gs_name")
) %>%
  filter(gs_collection_name == "Reactome Pathways") %>%
  # Then in this one, need to readjust the pval later, so
  # rename its existing padj to another name
  dplyr::rename(old_padj = padj) %>%
  dplyr::select(-c("gs_collection")) %>%
  tidyr::separate_wider_delim(
    group, delim = " | ",
    names = c("method", "dataset", "view"),
    too_many = "merge", too_few = "align_start"
  ) %>%
  group_by(method, dataset, view) %>%
  mutate(padj = p.adjust(pval, method="BH")) %>%
  ungroup()



# Should use a common cutoff
cutoff <- 0.2
message("\nUsing cutoff of: ", cutoff)

sig_df_top_k <- multimodal_msigdbr_df %>%
  mutate(method = standardize_method_names(method)) %>%
  filter(pval < cutoff) %>%
  group_by(method, dataset) %>%
  arrange(pval, .by_group = TRUE) %>%
  slice_head(n = 30) %>%
  ungroup()





pathway_sets_top_k <- sig_df_top_k %>%
  group_by(method, dataset) %>%
  summarise(pathways = list(pathway)) %>%
  mutate(label = paste(method, dataset, sep = " | ")) %>%
  ungroup()



# 2. Vectorized pairwise Jaccard using outer + mapply
sets <- pathway_sets_top_k$pathways
names(sets) <- pathway_sets_top_k$label
n <- length(sets)

# Compute full pairwise Jaccard matrix
jaccard_mat <- outer(seq_len(n), seq_len(n), FUN = Vectorize(function(i, j) {
  a <- sets[[i]]
  b <- sets[[j]]
  # This calculates the jaccard here
  length(intersect(a, b)) / length(union(a, b))
}))
rownames(jaccard_mat) <- names(sets)
colnames(jaccard_mat) <- names(sets)

library(ComplexHeatmap)
library(circlize)

datasets <- unique(pathway_sets_top_k$dataset)

plots <- purrr::map(datasets, function(ds) {
  idx <- pathway_sets_top_k$dataset == ds
  sub_mat <- jaccard_mat[idx, idx]

  # Clean up row/col names to just method
  methods <- pathway_sets_top_k$method[idx]
  rownames(sub_mat) <- methods
  colnames(sub_mat) <- methods

  Heatmap(sub_mat,
          name = "Jaccard",
          col = colorRamp2(c(0, 0.5, 1), c("white", "steelblue", "darkblue")),
          column_title = ds,
          border = T,
          #cell_fun = function(j, i, x, y, width, height, fill) {
          #  val <- sub_mat[i, j]
            # White text on dark cells, black on light
          #  txt_col <- ifelse(val > 0.5, "white", "black")
            #grid.text(sprintf("%.2f", val), x, y,
            #          gp = gpar(fontsize = 7, col = txt_col))
          #},
          row_names_gp = gpar(fontsize = 8),
          column_names_gp = gpar(fontsize = 8),
          cluster_rows = TRUE,
          cluster_columns = TRUE
  )
})

# Draw side by side
ht_list <- Reduce(`+`, plots)
draw(ht_list, column_title = "Pairwise Jaccard of Top-K Pathways")
