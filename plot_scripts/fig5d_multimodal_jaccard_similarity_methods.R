library(dplyr)
library(ggplot2)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source("src/common_helpers/save_plot_both.R")


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


multimodal_msigdbr_df
# Should use a common cutoff
cutoff <- 0.2
top_k <- 30
message("\nUsing cutoff of: ", cutoff)
message("\nLooking at top k: ", top_k, " pathways of each methods by raw pval")

sig_df_top_k <- multimodal_msigdbr_df %>%
  mutate(method = standardize_method_names(method)) %>%
  filter(pval < cutoff) %>%
  group_by(method) %>%
  arrange(pval, .by_group = TRUE) %>%
  slice_head(n = top_k) %>%
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

# =======================
text_size <- 45

jaccard_ht <- Heatmap(jaccard_mat,
                      name = "Jaccard",
                      col = jaccard_col,
                      #col = colorRamp2(c(0, 0.5, 1), c("white", "steelblue", "darkblue")),
                      #column_title = "Pairwise Jaccard Similarity of Top-K Pathways (Pooled Across Datasets)",
                      column_title = NULL,
                      cell_fun = function(j, i, x, y, width, height, fill) {
                        val <- jaccard_mat[i, j]
                        txt_col <- ifelse(val > 0.5, "white", "black")
                        grid.text(sprintf("%.2f", val), x, y,
                                  gp = gpar(fontsize = 20, col = txt_col))
                      },
                      show_column_names = F,
                      row_names_gp = gpar(fontsize = 20),
                      column_names_gp = gpar(fontsize = 20),
                      column_names_rot = 90,
                      heatmap_legend_param = list(
                        direction="vertical"
                      ),
                      cluster_rows = TRUE,
                      cluster_columns = TRUE
)

out_plot <- grid.grabExpr(
  draw(jaccard_ht, merge_legends = TRUE,
       show_heatmap_legend = FALSE,
       heatmap_legend_side = "right",
       align_heatmap_legend = "heatmap_top",
       padding = unit(c(5, 5, 5, 30), "mm")  # bottom, left, top, right
  )
)

#the_plot <- out_plot

#ggsave("aaaa.png", the_plot, width=12, height=9, dpi=1200, units="in")

out_plot |>
  ggdraw()

output_png_path <- "results/multimodal/fig5d_multimodal_jaccard_similarity_methods.png"
save_plot_both(out_plot, output_png_path, width=12, height=8)
#message("\nDone fig5d multimodal method top K pathways jaccard similarity, see fig at: ", output_png_path)



