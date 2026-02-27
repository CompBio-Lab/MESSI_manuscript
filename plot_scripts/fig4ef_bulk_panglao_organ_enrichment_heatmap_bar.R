# Figure 4 Bulk Enrichment signif pathways by method and gene set collection
library(ComplexHeatmap)
library(ggplot2)
library(circlize)
library(cowplot)
library(dplyr)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/fig_fgsea_analysis/_utils.R"))
# Load common util
source(here::here("src/common_helpers/map_disease_name.R"))



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
  filter(!str_detect(dataset, "kipan")) %>%
  add_manual_label() %>%
  # Clean up method names
  mutate(
    method = method |>
      str_replace("-ncomp", "_ncomp") |>
      str_replace("-factor", "-Factor")
  ) %>%
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
  ungroup()



# Then make this wider data
wide_n_sig_tab <- filtered_results %>%
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

c
# =============================================================================
# PLOTTING OF THE HEATMAP
# =============================================================================
plot_heatmap <- function(plot_matrix, annotation_table, custom_method_palette, cutoff=0.2) {
  # Param of the cutoff
  pval <- cutoff
  # =========================================================
  # Then the annotations here
  row_ha <- rowAnnotation(
    Method = factor(
      annotation_table$method,
      levels = names(custom_method_palette)  # ensure order and completeness
    ),
    col = list(Method = custom_method_palette),
    annotation_legend_param = list(
      Method = list(
        title_gp = gpar(fontsize = 9),
        labels_gp = gpar(fontsize = 8),
        nrow=4
      )
    ),
    show_annotation_name = FALSE,
    show_legend=TRUE
    #Dataset = factor(annotation_table$dataset, levels = unique(annotation_table$dataset))
  )

  col_ha <- columnAnnotation(
    # First 4 columns are "method", "dataset", "n", "group_num", so that's why
    # start from 5
    Organ = factor(annotation_table[5:ncol(annotation_table)] %>%
                     colnames()),
    show_annotation_name = FALSE
  )

  # Get the disease name of dataset from the src/common_helpers/map_disease_name.R
  mapped_disease_name <- tolower(annotation_table$dataset) %>% map_disease_name()

  # Add number into the heatmap to show the actual ratio
  # Function of color
  col_fun <- colorRamp2(c(0, 0.5, 1), c("white", "steelblue1", "blue"))
  #col_fun <- colorRamp2(c(0, 0.5, 1), c("white", "gainsboro", "lightgrey"))
  # Leave this as is, if not then go back to patchy problem
  # Y-axis to actual name of the dataset
  # Add own labelling vector to "link" dataset, since
  # they could be colated
  # Row split could be customized
  htmp <- Heatmap(
    plot_matrix,
    name = paste0("Proportion of significant cells at p < ", pval),
    col = col_fun,
    right_annotation = row_ha,
    # This map_name is custom function found in _utils.R of the same dir
    row_split = mapped_disease_name,
    cluster_rows = TRUE,
    #column_split = annotation_table$method,
    border = TRUE,
    row_title_rot = 0,
    row_gap = unit(2, "mm"),
    column_names_rot = 45,
    row_names_gp = gpar(fontsize = 10),
    row_title_gp = gpar(fontsize = 10),
    show_row_names = FALSE,
    cluster_columns = TRUE,
    #cluster_rows = FALSE,
    row_dend_width = unit(1.5, "cm"),
    cell_fun = function(j, i, x, y, width, height, fill) {
      text_color <- get_text_color(fill)
      grid.text(sprintf("%.2f", plot_matrix[i, j]), x, y,
                gp = gpar(col = text_color, fontsize = 10))
    },
    # Assign legend
    heatmap_legend_param = list(
      at = c(0, 0.5, 1),
      labels = c("Low", "", "High"),
      title = bquote(bold("Proportion of significant cells at ") * italic("p") < .(pval)),
      grid_height = unit(0.3, "cm"), grid_width = unit(0.3, "cm"),
      legend_width = unit(5, "cm"),
      #labels_gp = gpar(fontsize = text_size - 5),
      legend_direction = "horizontal"
      #legend_direction = "vertical"
    ),

  )


  # Draw heatmap and convert to grob
  ht_grob <- grid.grabExpr(
    #draw(ht, heatmap_legend_side="bottom", annotation_legend_side="right",
    #     legend_grouping = "original")
    draw(htmp, merge_legends = TRUE,
         heatmap_legend_side = "bottom",
         annotation_legend_side = "bottom"
    )
  )


  return(ht_grob)
}
# =============================================================================
# PLOTTING OF THE BAR PLOT COUNT BASED ON HEATMAP
# =============================================================================
plot_annot_bar <- function(methods, custom_method_palette) {


  # The frequency plot
  annot_bar_plot <- methods %>%
    table() %>%
    tibble::enframe(name="method", value="n") %>%
    mutate(n = as.integer(n)) %>%
    ggplot(aes(x=reorder(method, n), y=n, fill=method)) +
    geom_bar(stat="identity", width=0.7) +
    labs(x=NULL, y="Frequency", fill="Method")+
    scale_fill_manual(values = custom_method_palette, guide="note") +
    theme_bw() +
    # And remove horizontal lines
    theme(
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      axis.text.y        = element_text(size = 9)
    ) +
    coord_flip()
  return(annot_bar_plot)
}

# Extract the plot matrix from annotations
plot_matrix <- wide_n_sig_tab %>%
  dplyr::select(-c("method", "dataset", "n", "group_num")) %>%
  as.matrix()
# Also get the custom method colors
custom_method_palette <- get_method_custom_colors()

# The heatmap plot goes here
ht_grob <- plot_heatmap(
  plot_matrix=plot_matrix, annotation_table=wide_n_sig_tab,
  custom_method_palette=custom_method_palette,
  cutoff=cutoff
)

# Count method appearance as bars
annot_bar_plot <- plot_annot_bar(
  methods=wide_n_sig_tab$method,
  custom_method_palette=custom_method_palette
)

# And combine them together
out_plot <- plot_grid(
  ggdraw(ht_grob),
  annot_bar_plot +
    xlab(NULL) +
    guides(fill="none"),
  ncol = 2,
  rel_widths = c(2, 1)
)


output_png_path <- "fig4ef_bulk_panglao_organ_enrichment.png"

ggsave(output_png_path, out_plot, width = 12, height=12)
message("\nDone fig4ef bulk panglao organ enrichment, see fig at", output_png_path)

#print(out_plot)
