# Figure 5 Multimodal Enrichment signif pathways by method and gene set collection

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
  mutate(padj = p.adjust(pval, method="BH"))


# Should use a common cutoff
#cutoff <- 0.2
cutoff <- 0.05
message("\nUsing cutoff of: ", cutoff)

multimodal_msig_summary_df <- multimodal_msigdbr_df |>
  filter(padj < cutoff) %>%
  # TODO: move this fix to somewhere else
  dplyr::mutate(
    method = stringr::str_replace(method, "-ncomp", "_ncomp")
  ) %>%
  # Capitalize or to upper the method names
  mutate(method = standardize_method_names(method)) %>%
  group_by(method, dataset) %>%
  summarize(n_sig = n(), .groups = "drop")
  #group_by(method, dataset) %>%
  #summarize(mean_n_sig = mean(n_sig, na.rm=T),
  #          sd_n_sig = sd(n_sig, na.rm=T),
  #          .groups = "drop")


multimodal_msigdbr_df
  filter(padj < cutoff) %>%
  dplyr::select(pathway, padj,  NES, size, method, dataset, view) %>%
  group_by(method, dataset, view) %>%
  arrange(desc(abs(NES))) %>%
  slice_head(n=20) %>%
  ggplot(aes(x=NES, y=pathway, color=method, size=size)) +
  geom_point()

#out_plot <- plot_bar(multimodal_msig_summary_df)
#output_png_path <- "fig5cd_multimodal_sig_pathways_count.png"

#ggsave(output_png_path, out_plot, width = 12, height=8)
#message("\nDone fig5CD multimodal significant pathways counts, see fig at: ", output_png_path)

#print(out_plot)
