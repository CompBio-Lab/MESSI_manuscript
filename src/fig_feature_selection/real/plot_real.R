doc <- "

This script is used to create figure 3 of feature selection for real data.

Usage:
  plot_real.R [options]

Options:
  --input_path=INPUT      Path to read in the feature selection result
  --output_path=OUTPUT    Path to write out output plot
  --width=WIDTH           Width of the graph [default: 7]
  --height=height         Height of the graph [default: 7]
  --device=DEVICE         Device to print out [default: png]
  --dpi=DPI               Dots per inch [default: 300]
  --show_title=ST         Show plot title [default: 1]
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)
library(grid)
suppressPackageStartupMessages(library(ComplexHeatmap))
library(cowplot)

#dd <- readRDS("data/processed/fig_feature_selection_sim_plot_data.rds")

# Function to determine text color based on background color
get_text_color <- function(fill_color) {
  rgb <- col2rgb(fill_color)
  luminance <- (0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]) / 255
  ifelse(luminance < 0.5, "white", "black")
}



# This function plots heatmap for visualizing real data feature
# selection ranking and taken the spearson correlation
plot_real_heatmap <- function(
    input_data, heatmap_title="Spearson rank correlation on real datasets",
    text_size=12, method_palette="Paired", dataset_palette="Pastel1") {

  cor_mat <- input_data

  methods <- rownames(cor_mat)
  # Assign the colors
  # For the method to use default Paired
  method_colors <- RColorBrewer::brewer.pal(n=length(methods), method_palette)
  names(method_colors) <- methods
  # For the dataset to use default Pastel 2
  #dataset_palette <- "Pastel1"
  datasets <- colnames(cor_mat)
  dataset_colors <- RColorBrewer::brewer.pal(n=256, dataset_palette) |> tail(length(datasets))
  names(dataset_colors) <- datasets
  # Col wise
  col_ha <- columnAnnotation(
    Method = methods,
    #Dataset = datasets,
    col = list(
      Method = method_colors
      #Dataset = dataset_colors
    ),
    show_annotation_name = F,
    show_legend = F
  )

  row_ha <- rowAnnotation(
    #Dataset = datasets,
    Method = methods,

    col = list(
      Method = method_colors
      #Dataset = dataset_colors
    ),
    show_annotation_name = F,
    show_legend = T
  )
  # Custom color
  # Create the color mapping function
  col_fun <- circlize::colorRamp2(c(-1, 0, 1), c("blue", "white", "red"))
  #col_fun <- RColorBrewer::brewer.pal(n=11, "RdYlBu")
  # Plot the heatmap

  set.seed(1)
  real_ht <- Heatmap(
    cor_mat,
    col = col_fun,
    heatmap_legend_param = list(
      #title = "Spearman correlation",
      title = "Pearson correlation",
      title_gp = gpar(fontsize = text_size - 4, fontface = "bold"),
      #legend_direction = "horizontal",
      at = c(round(min(cor_mat), 1), round(median(cor_mat), 1), ceiling(max(cor_mat))),
      labels = c("Low", "", "High"),
      legend_direction = "vertical"
    ),
    #name = "Spearman Correlation",
    row_title = NULL,
    column_title = heatmap_title,
    column_title_gp = gpar(fontsize=text_size, fontface="bold"),
    row_names_gp = gpar(fontsize = text_size),
    column_names_gp = gpar(fontsize = text_size),
    show_row_dend = T,
    column_km = 2,
    row_km = 2,
    border = T,
    column_dend_height = unit(0.75, "cm"),
    cluster_rows = T,
    cluster_columns =  T,
    row_dend_side = 'left',
    row_dend_reorder = T,
    row_dend_width = unit(1, "cm"),
    cell_fun = function(j, i, x, y, width, height, fill) {
      text_color <- get_text_color(fill)
      grid.text(
        sprintf("%.3f", cor_mat[i, j]),
        x, y,
        gp = gpar(col = text_color, fontsize = 12)
      )
    },
    column_dend_reorder = T,
    column_names_rot = 45,
    show_row_names = F,
    show_column_names = T,
    show_parent_dend_line = FALSE,
    top_annotation = col_ha,
    right_annotation = row_ha
  )

  #return(real_ht)
  real_data_heatmap_plot <- grid.grabExpr(
    draw(real_ht, merge_legends = TRUE,
         #heatmap_legend_side = "bottom",
         #annotation_legend_side = "bottom")
         heatmap_legend_side = "right",
         annotation_legend_side = "right")
  )
  return(real_data_heatmap_plot)
}
# ==============================================================================
# Parse the cli

opt <- docopt::docopt(doc)

# Convenient vars
input_path <- opt$input_path
output_path <- opt$output_path
# Plot params
# text_size <- 12 # For doc knitting
text_size <- 14 # For slide
width <- as.numeric(opt$width)
height <- as.numeric(opt$height)
device <- opt$device
dpi <- as.numeric(opt$dpi)
method_palette <- "Paired"
show_title <- opt$show_title |> as.integer() |> as.logical()
# ==============================================================================
input_data <- readRDS(input_path)
# Plot it
out_plot <- plot_real_heatmap(input_data, text_size = text_size)

if (!show_title) {
  out_plot <- out_plot + theme(legend.title = element_blank())
}
# TODO: making a placeholder now for sim data
ggsave(output_path, plot = out_plot,
      width = width, height = height, device=device, dpi=dpi, bg="white")

saveRDS(out_plot,
        file = here::here("data/processed/feature_selection_real.rds")
)
message("Saved image of ", width, " x ", height, " to ", output_path)



