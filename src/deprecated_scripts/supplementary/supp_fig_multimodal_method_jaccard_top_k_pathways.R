
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
  group_by(method) %>%
  arrange(pval, .by_group = TRUE) %>%
  slice_head(n = 30) %>%
  ungroup()

# Pool all top-K pathways across datasets into one set per method
pathway_sets_method <- sig_df_top_k %>%
  group_by(method) %>%
  summarise(pathways = list(unique(pathway)), .groups = "drop")

# Compute pairwise Jaccard matrix
sets <- pathway_sets_method$pathways
names(sets) <- pathway_sets_method$method
n <- length(sets)

jaccard_mat <- outer(seq_len(n), seq_len(n), FUN = Vectorize(function(i, j) {
  a <- sets[[i]]
  b <- sets[[j]]
  length(intersect(a, b)) / length(union(a, b))
}))
rownames(jaccard_mat) <- names(sets)
colnames(jaccard_mat) <- names(sets)

# Plot
library(ComplexHeatmap)
library(circlize)

Heatmap(jaccard_mat,
        name = "Jaccard",
        col = colorRamp2(c(0, 0.5, 1), c("white", "steelblue", "darkblue")),
        column_title = "Pairwise Jaccard Similarity of Top-K Pathways (Pooled Across Datasets)",
        cell_fun = function(j, i, x, y, width, height, fill) {
          val <- jaccard_mat[i, j]
          txt_col <- ifelse(val > 0.5, "white", "black")
          grid.text(sprintf("%.2f", val), x, y,
                    gp = gpar(fontsize = 8, col = txt_col))
        },
        row_names_gp = gpar(fontsize = 9),
        column_names_gp = gpar(fontsize = 9),
        column_names_rot = 45,
        cluster_rows = TRUE,
        cluster_columns = TRUE
)


# ==============================

# Count how many methods identify each pathway
pathway_freq <- sig_df_top_k %>%
  distinct(method, pathway) %>%
  # For each pathway remove all the _
  mutate(pathway =  str_remove(pathway, "^REACTOME_") |>
           str_replace_all("_", " ") |>
           str_to_title()) %>%
  count(pathway, name = "n_methods") %>%
  arrange(desc(n_methods))


# Top pathways x methods binary heatmap
top_pathways <- pathway_freq %>% filter(n_methods >= 3) %>% pull(pathway)

binary_mat <- sig_df_top_k %>%
  distinct(method, pathway) %>%
  # For each pathway remove all the _
  mutate(pathway =  str_remove(pathway, "^REACTOME_") |>
           str_replace_all("_", " ") |>
           str_to_title()) %>%
  filter(pathway %in% top_pathways) %>%
  mutate(present = 1) %>%
  tidyr::pivot_wider(names_from = method, values_from = present, values_fill = 0) %>%
  tibble::column_to_rownames("pathway") %>%
  as.matrix()

Heatmap(binary_mat,
        name = "Found",
        col = c("0" = "grey95", "1" = "steelblue"),
        column_title = "Pathway Recovery Across Methods",
        row_names_gp = gpar(fontsize = 7),
        column_names_gp = gpar(fontsize = 8),
        column_names_rot = 45,
        cluster_rows = TRUE,
        cluster_columns = TRUE
)

sig_df_top_k %>%
  mutate(label = paste0(str_remove(dataset, "_omics"), "-", view)) %>%
  distinct(method, label, pathway) %>%
  count(method, label) %>%
  ggplot(aes(x = reorder(method, n, sum), y = n, fill = label)) +
  geom_col() +
  coord_flip() +
  scale_fill_brewer(palette = "Set2") +
  labs(x = NULL, y = "Number of Top-K Pathways", fill = "Dataset",
       title = "Pathway Contributions by Modality") +
  theme_minimal()
