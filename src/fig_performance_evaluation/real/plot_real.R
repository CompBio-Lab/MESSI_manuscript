doc <- "

This script is used to create figure of performance evaluation for real data

Usage:
  plot_real.R [options]

Options:
  --input_path=INPUT      Path to load input data
  --output_path=OUTPUT    Path to write out plot
  --width=WIDTH           Width of the graph [default: 7]
  --height=height         Height of the graph [default: 7]
  --device=DEVICE         Device to print out [default: png]
  --dpi=DPI               Dots per inch [default: 300]
"

# Parse doc
opt <- docopt::docopt(doc)

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)
library(grid)
#library(tibble)
suppressPackageStartupMessages(library(ComplexHeatmap))
# ==============================================================================


# Function to determine text color based on background color
get_text_color <- function(fill_color) {
  rgb <- col2rgb(fill_color)
  luminance <- (0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]) / 255
  ifelse(luminance < 0.5, "white", "black")
}



# This function has the details of making heatmap to ilustrate
# ranking of methods along the datasets
# I.e. Given method m1, m2, m3, m4 and dataset d1, d2,d3
# The rank in d1 could be m1 = 1, m2 = 4, m3 = 2, m4 = 3, where m2 is the best in d1
# The rank in d2 could be m1 = 3, m2 = 1, m3 = 2, m4 = 4, where m4 is the best in d2
plot_fig1_real <- function(
    input_data, text_size=12, method_palette="Paired", dataset_palette="Pastel1",
    heatmap_title = "Mean AUC (5-fold CV) ranking in real datasets") {
  # Then now the figure for mean auc ranking in real data
  if (!is.list(input_data)) stop("Plot data of real data should be a list")
  if (!all(names(input_data) %in% c("auc_matrix", "rank_matrix"))) {
    stop("Plot data of real data should have 'auc_matrix' and 'rank_matrix'")
  }

  auc_matrix <- input_data$auc_matrix
  rank_matrix <- input_data$rank_matrix

  methods <- rownames(rank_matrix)
  #datasets <- colnames(rank_matrix)

  # Assign the colors
  # For the method to use default Paired
  method_colors <- RColorBrewer::brewer.pal(n=length(methods), method_palette)
  names(method_colors) <- methods
  # For the dataset to use default Pastel1
  #dataset_colors <- RColorBrewer::brewer.pal(n=256, dataset_palette) %>% tail(length(datasets))
  #names(dataset_colors) <- datasets

  # Then annotations of the heatmap to use

  # Column wise
  col_ha <- HeatmapAnnotation(
    Method = methods,
    #Dataset = datasets,
    col = list(
      #Dataset = dataset_colors,
      Method = method_colors
    ),
    show_annotation_name = FALSE
  )


  # Row wise
  # row_ha <- rowAnnotation(
  #   Dataset = datasets,
  #   #Method = methods,
  #   col = list(
  #     #Method = method_colors
  #     Dataset = dataset_colors
  #   ),
  #   show_legend = T,
  #   show_annotation_name = FALSE
  # )

  # Useful vars to use later
  min_rank <- min(rank_matrix)
  med_rank <- median(rank_matrix) |> floor()
  max_rank <- max(rank_matrix)

  n_colors <- length(methods)

  # Plot the heatmap
  #col_fun <- viridis::cividis(256)
  #RColorBrewer::brewer.pal(n=11, name="RdYlBu")
  #col_fun = circlize::colorRamp2(c(1, 3 , 6), c("white", "#FFCCCC", "#8B0000"))
  col_fun = viridis::mako(n = 256)
  #col_fun = viridis::inferno(n = 256)
  #col_fun = viridis::magma(n = 256)
  #col_fun <- circlize::colorRamp2()
  ht <- Heatmap(
    t(rank_matrix),
    col = col_fun,
    border = T,
    column_title = heatmap_title,
    column_title_gp = gpar(fontsize=text_size, fontface="bold"),
    row_names_rot = 0,
    column_names_rot = 50,
    #column_labels = rownames(rank_matrix),
    row_title = NULL,
    cluster_rows = T,
    column_dend_reorder = T,
    row_dend_reorder = T,
    show_parent_dend_line = F,
    #row_labels = datasets,
    column_dend_height = unit(0.75, "cm"),
    show_row_names = T,  show_column_names = T,
    # cell_fun = function(j, i, x, y, width, height, fill) {
    #   grid.text(sprintf("%.2f", t(auc_matrix)[i, j]), x, y,
    #             gp = gpar(fontsize = 10,
    #                       col="darkblue",
    #                       fontface="bold"
    #                       )
    #             )
    #   },
    cell_fun = function(j, i, x, y, width, height, fill) {
      text_color <- get_text_color(fill)
      grid.text(
        sprintf("%.3f", t(auc_matrix)[i, j]),
        x, y,
        gp = gpar(col = text_color, fontsize = 12)
      )
    },
    # Assign legend
    heatmap_legend_param = list(
      title = "Ranking",
      legend_direction = "horizontal",
      at = c(min_rank, med_rank, max_rank),
      labels = c(
        paste0(min_rank, " (Worst) "),
        med_rank,
        paste0(max_rank, " (Best) ")
        )
    ),
    #top_annotation = col_ha,
    #right_annotation = row_ha
  )


  heatmap_p <- grid.grabExpr(
    #draw(ht, heatmap_legend_side="bottom", annotation_legend_side="right",
    #     legend_grouping = "original")
    draw(ht, merge_legends = TRUE,
    heatmap_legend_side = "bottom",
    annotation_legend_side = "bottom")
  )
  return(heatmap_p)
}


# ==============================================================================
# Plot here
# Load the variables from cli
input_path <- here::here(opt$input_path)
output_path <- here::here(opt$output_path)
# Plot params
method_palette <- "Paired"
dataset_palette <- "Pastel1"
text_size <- 12
width <- as.numeric(opt$width)
height <- as.numeric(opt$height)
device <- opt$device
dpi <- as.numeric(opt$dpi)

# ================================
# And load the input data
input_data <- readRDS(input_path)


# Verbose message
message("\nRendering figure of performance evaluation of classification")
message("\nInput path: ", input_path)


out_plot <- plot_fig1_real(
  input_data = input_data,
  text_size = text_size,
  method_palette = method_palette,
  dataset_palette = dataset_palette,
  heatmap_title = NULL
)

# Lastly save it to output
ggsave(output_path, plot = out_plot, width = width, height = height,
       device = device, dpi = dpi, create.dir = TRUE)

saveRDS(out_plot,
        file = here::here("data/processed/perf_evaluation_real.rds")
)

message("Saved image of ", width, " x ", height, " to ", output_path)



