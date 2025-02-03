doc <- "

This script is used to create figure of performance evaluation

Usage:
  plot.R [options]

Options:
  --input_path=INPUT      Path to load input data
  --output_path=OUTPUT    Path to write out plot
  --width=WIDTH           Width of the graph [default: 7]
  --height=height         Height of the graph [default: 7]
  --device=DEVICE         Device to print out [default: png]
  --dpi=DPI               Dots per inch [default: 300]
  --data_type=DATA_TYPE   Type of data to processed. One of real, sim [default: real]
"

# Parse doc
opt <- docopt::docopt(doc)

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)
library(tibble)
library(here)
library(stringr)
library(tidyr)
suppressPackageStartupMessages(library(ComplexHeatmap))
# ==============================================================================


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
  datasets <- colnames(rank_matrix)

  # Assign the colors
  # For the method to use default Paired
  method_colors <- RColorBrewer::brewer.pal(n=length(methods), method_palette)
  names(method_colors) <- methods
  # For the dataset to use default Pastel1
  dataset_colors <- RColorBrewer::brewer.pal(n=256, dataset_palette) %>% tail(length(datasets))
  names(dataset_colors) <- datasets

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
  row_ha <- rowAnnotation(
    Dataset = datasets,
    #Method = methods,
    col = list(
      #Method = method_colors
      Dataset = dataset_colors
    ),
    show_legend = T,
    show_annotation_name = FALSE
  )

  # Plot the heatmap
  #col_fun <- viridis::cividis(256)
  #RColorBrewer::brewer.pal(n=11, name="RdYlBu")
  col_fun = circlize::colorRamp2(c(1, 3 , 6), c("white", "#FFCCCC", "#8B0000"))
  #col_fun <- viridis::mako(256)
  #col_fun <- viridis::rocket(256)
  #col_fun <- circlize::colorRamp2()
  ht <- Heatmap(
    t(rank_matrix),
    col = col_fun,
    border = T,
    column_title = heatmap_title,
    column_title_gp = gpar(fontsize=text_size, fontface="bold"),
    row_names_rot = 0,
    column_names_rot = 45,
    #column_labels = rownames(rank_matrix),
    row_title = NULL,
    cluster_rows = T,
    column_dend_reorder = T,
    row_dend_reorder = T,
    show_parent_dend_line = F,
    #row_labels = datasets,
    column_dend_height = unit(2.5, "cm"),
    show_row_names = T,  show_column_names = T,
    cell_fun = function(j, i, x, y, width, height, fill) {
      grid.text(sprintf("%.2f", t(auc_matrix)[i, j]), x, y,
                gp = gpar(fontsize = 10,
                          col="darkblue",
                          fontface="bold"
                          )
                )
      },
    # Assign legend
    heatmap_legend_param = list(
      title = "Ranking",
      legend_direction = "horizontal",
      at = seq(1, 6, 1)
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
# For sim data, boxplot stratify by params
# This function has details of showing boxplot facet by correlation and
# effect combination in intersim strategy simulated data
plot_fig1_sim <- function(
    input_data, text_size=12,
    x_lab = "Method", y_lab="Mean Auc Score from 5-fold CV",
    method_palette="Paired") {

  if (!is.data.frame(input_data)) stop("Plot data for simulated data should be dataframe")
  sim_df <- input_data

  # Labeller for facetting
  signal_labels <- paste0("Signal = ", sim_df$signal |> unique())
  names(signal_labels) <- sim_df$signal |> unique()
  corr_labels <- paste0("Cor = ", sim_df$corr |> unique())
  names(corr_labels) <- sim_df$corr |> unique()
  # Then the plotting
  p <- sim_df %>%
    ggplot(aes(x=method, y=auc_mean, fill=method)) +
    stat_boxplot(geom ='errorbar', width=0.25) +
    geom_boxplot()+
    scale_fill_brewer(palette = method_palette) +
    facet_grid(
      signal~corr,
      labeller = labeller(signal = signal_labels, corr = corr_labels),
      scales = "free"
    ) +
    theme_bw() +
    # And change Grid label names
    theme(
      # Rotate text of methods names
      #axis.text.x = element_text(angle = 45, hjust=1),
      axis.text.x = element_blank(),
      axis.text.y = element_text(
        size = text_size
      ),
      axis.title = element_text(size = text_size + 2),
      axis.ticks.x = element_blank(),
      strip.text.x = element_text(
        size = text_size, color = "red", face = "bold.italic"
      ),
      # TODO: Maybe consider changing color of the grid ribbon color?
      #strip.background.x = element_rect(fill="blue"),
      strip.text.y = element_text(
        size = text_size, color = "red", face = "bold.italic"
      ),
      legend.title = element_text(size = text_size + 2),
      legend.text = element_text(size = text_size),
      legend.position = "bottom"
    ) +
    guides(fill = guide_legend(nrow = 2)) +
    # Lastly the labels
    labs(x=x_lab, fill=x_lab, y = y_lab)
  return(p)
}


# ==============================================================================
# Plot here conditionally


# Load the variables from cli
input_path <- here(opt$input_path)
output_path <- here(opt$output_path)
data_type <- opt$data_type
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

# Then call the function depending on data type
if (data_type == "real") {
  out_plot <- plot_fig1_real(
    input_data = input_data,
    text_size = text_size,
    method_palette = method_palette,
    dataset_palette = dataset_palette,
    heatmap_title = NULL
  )

}

if (data_type == "sim") {
  out_plot <- plot_fig1_sim(
    input_data = input_data,
    text_size = text_size,
    method_palette = method_palette
  )
}


# Lastly save it to output
ggsave(output_path, plot = out_plot, width = width, height = height,
       device = device, dpi = dpi, create.dir = TRUE)
message("Saved image of ", width, " x ", height, " to ", output_path)



