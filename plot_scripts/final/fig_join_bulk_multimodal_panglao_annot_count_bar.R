# Figure 4 Bulk Enrichment signif pathways by method and gene set collection
library(ComplexHeatmap)
library(ggplot2)
library(circlize)
library(cowplot)
library(dplyr)
source("src/common_helpers/standardize_data_funs.R")
# Load common util
source(here::here("src/common_helpers/map_disease_name.R"))
source(here::here("plot_scripts/fgsea_utils.R"))
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))

plot_fig_join_bulk_multimodal_panglao_annot_count_bar <- function(output_path=NULL, text_size=7) {
  if (is.null(output_path)) {
    output_path <- "results/join_bulk_multimodal/fig_join_bulk_multimodal_panglao_annot_count_bar.png"
  }
  message("\nUsing text size: ", text_size)

  df <- data.table::fread("data/processed/bulk/bulk_panglao_fgsea.csv")
  panglao_pathways <- readRDS("data/processed/pathways_db/panglao_pathways_collection.rds")
  # Now combine the pathways collection name into one df
  bulk_panglao_df <- inner_join(
    df, panglao_pathways,
    by = c("pathway" = "gs_name")
  ) %>%
    # Then in this one, need to readjust the pval later, so
    # rename its existing padj to another name
    dplyr::rename(old_padj = padj) %>%
    tidyr::separate_wider_delim(
      group, delim = " | ",
      names = c("method", "dataset", "view"),
      too_many = "merge", too_few = "align_start"
    ) %>%
    # Drop extra dataset
    #filter(!(dataset %in% c("tcga-chol", "tcga-kipan"))) %>%
    group_by(method, dataset, view) %>%
    mutate(padj = p.adjust(pval, method="BH"))


  # Should use a common cutoff
  cutoff <- 0.2
  message("\nUsing cutoff of: ", cutoff)

  # First filter those that match organ of study with the organ of celltype
  filtered_results <- bulk_panglao_df %>%
    # Make everything lowercase first
    mutate(across(where(is.character), tolower)) %>%
    # Drop unwanted dataset early
    filter(!dataset %in% c("tcga-chol", "tcga-kipan")) %>%
    add_manual_label() %>%
    # Capitalize or to upper the method names
    mutate(method = standardize_method_names(method)) %>%
    # Filter rows where organ matches label
    filter(str_detect(organ_label, organ)) %>%
    # Add columns in one mutate block
    group_by(method, dataset) %>%
    mutate(
      padj = p.adjust(pval, method="BH"),
      cell_type = pathway,
      method_dataset = paste(method, dataset, sep = "_")
    ) %>%
    ungroup() %>%
    # Ignore the cells from immune system
    filter(!organ == "immune-system") %>%
    group_by(method, dataset, organ) %>%
    mutate(group_num = n()) %>%
    filter(padj < cutoff) %>%
    summarize(
      n = n(),
      group_num = unique(group_num),
      .groups = "drop"
    ) %>%
    ungroup() %>%
    mutate(ratio = n / group_num) %>%
    pivot_wider(names_from = organ, values_from = ratio, values_fill=0)

  # ===============================
  # And plotting goes here

  out_plot <- filtered_results$method %>%
    table() %>%
    tibble::enframe(name="method", value="n") %>%
    mutate(color_label = str_remove(method, "-.*") |> toupper()) %>%
    mutate(color_label = case_when(
      color_label == "CARET_MULTIMODAL" ~ "CARET",
      TRUE ~ color_label
    )) %>%
    mutate(n = as.integer(n)) %>%
    ggplot(aes(x=reorder(method, n), y=n, fill=color_label)) +
    geom_bar(stat="identity", width=0.7) +
    labs(x=NULL, y="Frequency", fill="Method")+
    scale_fill_manual(values = method_family_colors) +
    theme_bw(base_size=text_size) +
    # And remove horizontal lines
    theme(
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      axis.text.y        = element_text(size = text_size)
    ) +
    coord_flip()

  save_plot_both(out_plot, output_path, width=12, height=8)
  return(out_plot)
}

plot_fig_join_bulk_multimodal_panglao_annot_count_bar(
  output_path="results/join_bulk_multimodal/fig_join_bulk_multimodal_panglao_annot_count_bar.png",
  text_size=12
)

