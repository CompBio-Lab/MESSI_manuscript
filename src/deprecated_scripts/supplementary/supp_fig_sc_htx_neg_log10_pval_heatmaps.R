library(dplyr)
library(ggplot2)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source("src/common_helpers/save_plot_both.R")

input_path <- "data/processed/sc/sc_htx_msigdbr_fgsea.csv"
msigdbr_pathways <- readRDS("data/processed/pathways_db/msigdbr_pathways_collection.rds")
df <- data.table::fread(input_path)

# For the sc datasets should look at reactome pathways only
# Htx has mogonet in it, it has 3 views
sc_htx_msigdbr_df <- inner_join(
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
  ungroup() %>%
  # Clean up the pathway
  mutate(pathway = pathway %>%
           str_remove("^REACTOME_") %>%   # remove prefix
           str_replace_all("_", " ") %>%  # replace underscores with spaces
           str_to_title()                 )


#sc_htx_msigdbr_df %>%
#  write.csv("htx_pathways.csv", row.names = F)

# Overlap between top K features for a given cell across methods

# Pathway enrichment across celltypes and methods
# Should use a common cutoff
cutoff <- 0.2
top_k <- 5
message("\nUsing cutoff of: ", cutoff)
message("\nLooking at top k: ", top_k, " pathways of each methods by raw pval")

# ============================================================
# 1. Tile heatmap: use -log10(padj) instead of NES
# ============================================================

sig_paths <- sc_htx_msigdbr_df %>%
  filter(padj < cutoff)

top_paths <- sig_paths %>%
  group_by(method, view) %>%
  slice_min(padj, n = top_k, with_ties = FALSE) %>%
  pull(pathway) %>%
  unique()

top_paths
# Clean pathway names for display
clean_pathway <- function(x) {
  x %>%
    str_remove("^REACTOME_") %>%
    str_replace_all("_", " ") %>%
    str_to_sentence() %>%
    str_trunc(50)
}



tile_df <- sc_htx_msigdbr_df %>%
  filter(pathway %in% top_paths) %>%
  mutate(
    pathway_clean = clean_pathway(pathway),
    neg_log_padj = -log10(padj),
    sig_label = case_when(
      padj < 0.01 ~ "**",
      padj < 0.05 ~ "*",
      padj < 0.1  ~ "†",
      TRUE ~ ""
    )
  )

p_tile <- ggplot(tile_df, aes(x = method, y = reorder(pathway_clean, neg_log_padj), fill = neg_log_padj)) +
  geom_tile(color = "white", linewidth = 0.3) +
  geom_text(aes(label = sig_label), size = 3, vjust = 0.5) +
  scale_fill_viridis_c(
    option = "magma",
    direction = -1,
    name = expression(-log[10](p[adj])),
    na.value = "grey90"
  ) +
  facet_wrap(~view, scales = "free_y", ncol = 3) +
  labs(
    x = NULL, y = NULL,
    title = "Pathway enrichment across methods and cell types",
    subtitle = glue::glue("Top {top_k} pathways per method-celltype (padj < {cutoff}); † < 0.1, * < 0.05, ** < 0.01")
  ) +
  theme_minimal(base_size = 10) +
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1, size = 8),
    axis.text.y = element_text(size = 7),
    strip.text = element_text(face = "bold", size = 9),
    panel.grid = element_blank(),
    legend.position = "right"
  )

p_tile


