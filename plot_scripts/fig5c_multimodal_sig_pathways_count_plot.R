# Figure 5 Multimodal Enrichment signif pathways by method and gene set collection

library(dplyr)
library(ggplot2)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))



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
cutoff <- 0.2
#cutoff <- 0.05
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
  summarize(n_sig = n(), .groups = "drop") %>%
  group_by(method) %>%
  summarize(mean_n_sig = mean(n_sig, na.rm=T),
           sd_n_sig = sd(n_sig, na.rm=T),
           .groups = "drop") %>%
  mutate(color_label = str_remove(method, "-.*") |> toupper()) %>%
  mutate(color_label = case_when(
    color_label == "CARET_MULTIMODAL" ~ "CARET",
    TRUE ~ color_label
  ))

# #
# multimodal_msigdbr_df %>%
#   dplyr::filter(padj < cutoff) %>%
#   dplyr::select(pathway, padj,  NES, size, method, dataset, view) %>%
#   group_by(method, dataset, view) %>%
#   arrange(desc(abs(NES))) %>%
#   slice_head(n=20) %>%
#   ggplot(aes(x=NES, y=pathway, color=method, size=size)) +
#   geom_point()

plot_bar <- function(data,text_size=11) {
  # Grab method palette
  #custom_method_palette <- get_method_custom_colors()

  significant_pathways_method_gs_plot_obj <- data %>%
    mutate(x = forcats:::fct_reorder(method, mean_n_sig)) %>%
    ggplot(aes(x = x, y = mean_n_sig, fill = color_label)) +
    geom_errorbar(aes(ymin = mean_n_sig, ymax = mean_n_sig + sd_n_sig),
                  width = 0.25, color = "grey30", linewidth=0.4,
                  position = position_dodge(0.9)) +
    geom_bar(stat = "identity", width = 0.7) +
    labs(
      x     = NULL,
      fill  = "Method",
      y     = "# Significant Reactome Pathways",
      title = "Significant Reactome Pathways by Method"
    ) +
    theme_bw(base_size = text_size) +
    tidytext::scale_x_reordered() +
    scale_y_log10(expand = expansion(mult = c(0, 0.12))) +
    coord_flip() +
    scale_fill_manual(values = method_family_colors) +
    theme(
      plot.title         = element_text(hjust = 0.5),
      strip.background   = element_rect(fill = "grey95", color = "grey70"),
      strip.text         = element_text(face = "bold", size = text_size),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      legend.position    = "bottom"
    )

  return(significant_pathways_method_gs_plot_obj)
}


text_size <- 40
out_plot <- plot_bar(multimodal_msig_summary_df, text_size = text_size)
output_png_path <- "results/multimodal/fig5c_multimodal_sig_pathways_count.png"
# the_plot <- out_plot +
#   ggtitle(NULL) +
#   ylab("# Sig pathways") +
#   theme(legend.position = "none")
#
# the_plot
#the_gg <- get_legend_35(out_plot +
#  guides(fill = guide_legend(nrow=3,title=NULL)
#         )) %>%
#  cowplot::ggdraw()
  #ggsave("aaaa.png", . , width=12, height=4,dpi=1200, units="in")


#("aaaa.png", the_plot, width=12, height=9, dpi=1200, units="in")
save_plot_both(out_plot, output_png_path, width=12, height=8)
#message("\nDone fig5C multimodal significant pathways counts, see fig at: ", output_png_path)

#print(out_plot)
