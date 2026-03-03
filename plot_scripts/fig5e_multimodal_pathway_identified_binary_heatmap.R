
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

# Count how many methods identify each pathway
pathway_freq <- sig_df_top_k %>%
  distinct(method, pathway) %>%
  # For each pathway remove all the _
  mutate(pathway =  str_remove(pathway, "^REACTOME_") |>
           str_replace_all("_", " ") |>
           str_to_title()) %>%
  dplyr::count(pathway, name = "n_methods") %>%
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


# ===========================
text_size <- 40

bn_ht <- Heatmap(binary_mat,
                 name = "Found",
                 col = binary_colors,
                 #col = c("0" = "grey95", "1" = "steelblue"),
                 #column_title = "Pathway Recovery Across Methods",
                 column_title = NULL,
                 #row_names_gp = gpar(fontsize = text_size),
                 #column_names_gp = gpar(fontsize = text_size),
                 row_names_gp = gpar(fontsize = 11),
                 column_names_gp = gpar(fontsize = 12),
                 # Assign legend
                 heatmap_legend_param = list(
                   legend_direction = "horizontal"
                 ),
                 column_names_rot = 90,
                 cluster_rows = TRUE,
                 cluster_columns = TRUE,

)


out_plot <- grid.grabExpr(
  draw(bn_ht, merge_legends = TRUE,
       heatmap_legend_side = "right",
       align_heatmap_legend = "heatmap_top",
       padding = unit(c(5, 5, 5, 25), "mm")  # bottom, left, top, right
  )
)

#the_plot <- out_plot

#ggsave("aaaa.png", the_plot, width=12, height=8, dpi=1200, units="in")

output_png_path <- "results/multimodal/fig5e_multimodal_top_pathways_identified_binary_heatmap.png"
save_plot_both(out_plot, output_png_path, width=12, height=8)
#message("\nDone fig5e multimodal method top K pathways binary heatmap, see fig at: ", output_png_path)


