# Figure 4 Bulk Enrichment signif pathways by method and gene set collection
library(ComplexHeatmap)
library(ggplot2)
library(circlize)
library(cowplot)
library(dplyr)
source("src/common_helpers/standardize_data_funs.R")
# Load plotting helpers like colors
source(here::here("src/common_helpers/plot_utils.R"))
# Load common util
source(here::here("src/common_helpers/map_disease_name.R"))
source(here::here("plot_scripts/fgsea_utils.R"))
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))





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

# =============================================================================
# PLOTTING OF THE HEATMAP
# =============================================================================
plot_heatmap <- function(plot_matrix, annotation_table, custom_method_palette, cutoff=0.2, text_size=12) {
  # Param of the cutoff
  pval <- cutoff
  # =========================================================
  # UGGLY FIX HER
  annotation_table <- annotation_table %>%
    mutate(color_label = str_remove(method, "-.*") |> toupper()) %>%
    mutate(color_label = case_when(
      color_label == "CARET_MULTIMODAL" ~ "CARET",
      TRUE ~ color_label
    ))

  # =========================================================
  # Then the annotations here
  row_ha <- rowAnnotation(
    Method = factor(
      annotation_table$color_label,
      levels = names(method_family_colors)  # ensure order and completeness
    ),
    col = list(Method = method_family_colors),
    annotation_legend_param = list(
      Method = list(
        labels_gp = gpar(fontsize = text_size - 1.5),
        title_gp = gpar(fontsize=  text_size - 1.5, fontface="bold"),
        nrow=4
      )
    ),
    show_annotation_name = FALSE,
    show_legend=FALSE
    #Dataset = factor(annotation_table$dataset, levels = unique(annotation_table$dataset))
  )

  col_ha <- columnAnnotation(
    # First 4 columns are "method", "dataset", "n", "group_num", so that's why
    # start from 5
    Organ = factor(annotation_table[5:ncol(annotation_table)] %>%
                     colnames()),
    annotation_legend_param = list(
      Organ = list(
        title_gp = gpar(fontsize = text_size + 2),
        labels_gp = gpar(fontsize = text_size)
      )
    ),
    show_annotation_name = FALSE
  )

  # Get the disease name of dataset from the src/common_helpers/map_disease_name.R
  mapped_disease_name <- tolower(annotation_table$dataset) %>% map_disease_name()
  # Lastly make the colnames to title case
  colnames(plot_matrix) <- colnames(plot_matrix) |> tools::toTitleCase()

  # Add number into the heatmap to show the actual ratio
  # Function of color
  col_fun <- colorRamp2(c(0, 0.5, 1), c("white", "steelblue1", "royalblue"))
  #col_fun <- viridis::cividis(n=50)
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
    row_gap = unit(1, "mm"),
    column_names_rot = 45,
    column_names_gp = gpar(fontsize = text_size),
    row_names_gp = gpar(fontsize = text_size),
    row_title_gp = gpar(fontsize = text_size),
    show_row_names = FALSE,
    cluster_columns = TRUE,
    #cluster_rows = FALSE,
    row_dend_width = unit(1.5, "cm"),
    cell_fun = function(j, i, x, y, width, height, fill) {
      value <- plot_matrix[i, j]

      # If value is 0, override fill to light grey and don't draw text
      if (value == 0) {
        grid.rect(x, y, width, height, gp = gpar(fill = "grey90", col = NA))
      } else {
        # Draw the text for non-zero values
        text_color <- get_text_color(fill)
        grid.text(sprintf("%.2f", value), x, y,
                  gp = gpar(col = text_color, fontsize = text_size - 1.5))
      }
    },
    # Assign legend
    heatmap_legend_param = list(
      at = c(0, 0.5, 1),
      labels = c("Low", "", "High"),
      title = bquote("Proportion of significant cells at " * italic("p") < .(pval)),
      grid_height = unit(2, "mm"), grid_width = unit(2, "mm"),
      legend_width = unit(6.5, "cm"),
      labels_gp = gpar(fontsize = text_size - 1.5),
      title_gp = gpar(fontsize=  text_size - 1.5, fontface="bold"),
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
         #align_heatmap_legend = "global_center",
         annotation_legend_side = "bottom",
    )
  )


  return(ht_grob)
}
# =============================================================================
# PLOTTING OF THE BAR PLOT COUNT BASED ON HEATMAP
# =============================================================================
plot_annot_bar <- function(methods, custom_method_palette,text_size=12) {


  # The frequency plot
  annot_bar_plot <- methods %>%
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
  return(annot_bar_plot)
}



# Extract the plot matrix from annotations
plot_matrix <- wide_n_sig_tab %>%
  dplyr::select(-c("method", "dataset", "n", "group_num")) %>%
  as.matrix()
# Also get the custom method colors
custom_method_palette <- get_method_custom_colors()


# Use a custom text size
# size 12 for normal
# size 8 for publication
text_size <- 5.5
# The heatmap plot goes here
ht_grob <- plot_heatmap(
  plot_matrix=plot_matrix, annotation_table=wide_n_sig_tab,
  custom_method_palette=custom_method_palette,
  cutoff=cutoff,
  text_size=text_size
)

# Count method appearance as bars
annot_bar_plot <- plot_annot_bar(
  methods=wide_n_sig_tab$method,
  custom_method_palette=custom_method_palette,
  text_size=text_size
)

# And combine them together
out_plot <- plot_grid(
  ggdraw(ht_grob),
  annot_bar_plot +
    xlab(NULL) +
    guides(fill="none"),
  ncol = 2,
  rel_widths = c(1, 0.5)
)


output_png_path <- "results/bulk/fig4ef_bulk_panglao_organ_enrichment_heatmap.png"
save_plot_both(out_plot, output_png_path, width=7, height=7)

message("\nDone fig4ef bulk panglao organ enrichment, see fig at: ", output_png_path)

#print(out_plot)
