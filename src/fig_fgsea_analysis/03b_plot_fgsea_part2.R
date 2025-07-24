doc <- "

This script is used to plot fgsea part 2 results

Usage:
  03b_plot_fgsea_part2.R [options]

Options:
  --input_path=INPUT_PATH       File to load fgsea part1 summary
  --output_path=OUTPUT_PATH     File to output the plot data
  --width=WIDTH                 Width of the figure [default: 12]
  --height=HEIGHT               Height of the figure [default: 9]
"


library(data.table)
library(ComplexHeatmap)
library(ggplot2)
library(circlize)
library(cowplot)
suppressPackageStartupMessages(library(dplyr))

# Load other utilities
source(here::here("src/fig_fgsea_analysis/_utils.R"))
# Load common util
source(here::here("src/common_helpers/map_disease_name.R"))
# Load plotting helpers
source(here::here("src/common_helpers/plot_utils.R"))

# =============================================================================
# PLOTTING OF THE HEATMAP
# =============================================================================
plot_heatmap <- function(plot_matrix, annotation_table, custom_method_palette) {
  # =========================================================
  # Then the annotations here
  row_ha <- rowAnnotation(
    Method = factor(
      annotation_table$method,
      levels = unique(annotation_table$method)
    ),
    col = list(Method = custom_method_palette),
    annotation_legend_param = list(
      Method = list(
        #title_gp = gpar(fontsize = 16),
        #labels_gp = gpar(fontsize = 8),
        nrow=4
      )
    ),
    show_annotation_name = FALSE
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
  mapped_disease_name <- annotation_table$dataset %>% map_disease_name()

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
    name = "Proportion of significant cells",
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
         annotation_legend_side = "bottom")
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
    labs(x="Method", y="Frequency", fill="Method")+
    scale_fill_manual(values = custom_method_palette) +
    theme_bw() +
    # And remove horizontal lines
    theme(
      panel.grid.major.y = element_blank()
    ) +
    coord_flip()
  return(annot_bar_plot)
}

main <- function(input_path, output_path, width, height, method_palette="Paired") {
  if (is.null(input_path)) {
    input_path <- "data/processed/fgsea_part2_summary_df.csv"
  }

  if (is.null(output_path)) {
    output_path <- "data/processed/fig_fgsea_panel_b_plot_data.rds"
  }

  # Load the data here
  annotation_table <- fread(here::here(input_path))
  # Extract the plot matrix from annotations
  plot_matrix <- annotation_table %>%
    dplyr::select(-c("method", "dataset", "n", "group_num")) %>%
    as.matrix()
  # Also get the custom method colors
  custom_method_palette <- get_method_custom_colors(method_palette=method_palette)

  # The heatmap plot goes here
  ht_grob <- plot_heatmap(
    plot_matrix=plot_matrix, annotation_table=annotation_table,
    custom_method_palette=custom_method_palette
  )

  # Count method appearance as bars
  annot_bar_plot <- plot_annot_bar(
    methods=annotation_table$method,
    custom_method_palette=custom_method_palette
  )

  # And combine them together
  output_plot <- plot_grid(
    ggdraw(ht_grob),
    annot_bar_plot +
      xlab(NULL) +
      guides(fill="none"),
    ncol = 2,
    rel_widths = c(2, 1)
  )

  ggsave("results/figures/fig_fgsea_panelB.png", plot=output_plot, width=width, height=height)


  saveRDS(output_plot, here::here(output_path))
  message("\nSaved plot data for fgsea part 2 into ", output_path)

}

palette <- "Paired"

opt <- docopt::docopt(doc)
main(input_path=opt$input_path, output_path=opt$output_path,
     width=as.numeric(opt$width),
     height=as.numeric(opt$height),
     method_palette=palette)



# THIS IS STALE CODE
#
# methods <- annotation_table$method |> unique() |> sort()
# #
# # # Get a pastel color palette with the same number of colors as your methods
# n_methods <- length(methods)
# # # RColorBrewer's Pastel1 has up to 9 colors; use Pastel2 if you need more variation
# pastel_colors <- RColorBrewer::brewer.pal(n = n_methods, name = "Paired")
# #
# # # Create a named vector of colors for each method
# method_colors <- setNames(pastel_colors, methods)




