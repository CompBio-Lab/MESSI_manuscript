# Figure 4 Bulk Enrichment signif pathways by method and gene set collection

library(dplyr)
library(ggplot2)
library(forcats)
library(tidytext)


source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))



df <- data.table::fread("data/processed/bulk/bulk_msigdbr_fgsea.csv")
msigdbr_pathways <- readRDS("data/processed/pathways_db/msigdbr_pathways_collection.rds")



bulk_msigdbr_df <- inner_join(
  df, msigdbr_pathways,
  by = c("pathway" = "gs_name")
) %>%
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
message("\nUsing cutoff of: ", cutoff)

bulk_msig_summary_df <- bulk_msigdbr_df |>
  filter(padj < cutoff) %>%
  # TODO: move this fix to somewhere else
  dplyr::mutate(
    method = stringr::str_replace(method, "-ncomp", "_ncomp")
  ) %>%
  # Capitalize or to upper the method names
  mutate(method = standardize_method_names(method)) %>%
  #group_by(method, dataset, view, gs_collection_name) %>%
  group_by(method, dataset, gs_collection_name) %>%
  summarize(n_sig = n(), .groups = "drop") %>%
  group_by(method, gs_collection_name) %>%
  summarize(mean_n_sig = mean(n_sig),
            sd_n_sig = sd(n_sig),
            .groups = "drop") %>%
  mutate(color_label = str_remove(method, "-.*") |> toupper()) %>%
  mutate(color_label = case_when(
    color_label == "CARET_MULTIMODAL" ~ "CARET",
    TRUE ~ color_label
  ))


plot_bar <- function(data) {
  # Grab method palette
  custom_method_palette <- get_method_custom_colors()

  significant_pathways_method_gs_plot_obj <- data %>%
    # And reorder it for plotting
    dplyr::mutate(label_reordered = reorder_within(method, mean_n_sig, gs_collection_name)) %>%
    ggplot(aes(x = label_reordered, y = mean_n_sig, fill=color_label)) +
    geom_errorbar(aes(ymin = mean_n_sig, ymax = mean_n_sig + sd_n_sig),
                  width = 0.25, color = "grey30", linewidth=0.4,
                  position = position_dodge(0.9)) +
    geom_bar(stat = "identity", width=0.7) +
    facet_wrap(~ gs_collection_name, scales = "free") +
    labs(x = NULL, y = "Mean # Significant Pathways",
         fill = "Method",
         title = "Significant Pathways by Method and Gene Set Collection") +
    theme_bw(base_size=11) +
    tidytext::scale_x_reordered() +
    scale_y_log10(expand = expansion(mult = c(0, 0.12))) +
    coord_flip() +
    scale_fill_manual(values = method_family_colors) +
    theme(
      plot.title = element_text(hjust = 0.5),
      strip.background   = element_rect(fill = "grey95", color = "grey70"),
      strip.text         = element_text(face = "bold", size = 11),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      legend.position = "bottom"
    )

}





out_plot <- plot_bar(bulk_msig_summary_df)
output_png_path <- "results/bulk/fig4c_bulk_sig_pathways_bar_chart.png"
save_plot_both(out_plot, output_png_path, width=12, height=8)
message("\nDone fig4C bulk significant pathways counts, see fig at", output_png_path)

#print(out_plot)
