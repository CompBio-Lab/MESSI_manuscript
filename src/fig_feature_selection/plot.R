doc <- "

This script is used to create figure 3 of feature selection.

Usage:
  fig_feature_selection.R [options]

Options:
  --input_path=INPUT      Path to read in the feature selection result
  --output_path=OUTPUT    Path to write out output plot
  --width=WIDTH           Width of the graph [default: 7]
  --height=height         Height of the graph [default: 7]
  --device=DEVICE         Device to print out [default: png]
  --dpi=DPI               Dots per inch [default: 300]
  --data_type=DATA_TYPE   Type of data to processed. One of real, sim [default: real]
"

# Load libraries
suppressPackageStartupMessages(library(dplyr))
library(ggplot2)
library(stringr)
suppressPackageStartupMessages(library(ComplexHeatmap))
library(tidyr)




# This function plots heatmap for visualizing real data feature
# selection ranking and taken the spearson correlation
plot_real_heatmap <- function(
    wide_ranking_df, heatmap_title="Spearson rank correlation on real datasets",
    fontsize=12, method_palette="Paired", dataset_palette="Pastel1") {
  # Then calculate correlation matrix of real data now
  real_df <- wide_ranking_df %>%
    filter(is_simulated == "real")
  cor_mat <- real_df %>%
    select_if(is.numeric) %>%
    select(order(colnames(.))) %>%
    as.matrix() %>%
    cor(method="spearman")
  methods <- rownames(cor_mat)
  # Assign the colors
  # For the method to use default Paired
  method_colors <- RColorBrewer::brewer.pal(n=length(methods), method_palette)
  names(method_colors) <- methods
  # For the dataset to use default Pastel 2
  dataset_palette <- "Pastel1"
  datasets <- real_df$dataset %>% unique() %>% sort()
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
    show_annotation_name = F
  )

  row_ha <- rowAnnotation(
    #Dataset = datasets,
    Method = methods,

    col = list(
      Method = method_colors
      #Dataset = dataset_colors
    ),
    show_annotation_name = F,
    show_legend = F
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
      title = "Spearman correlation",
      legend_direction = "horizontal"
    ),
    #name = "Spearman Correlation",
    row_title = NULL,
    column_title = heatmap_title,
    column_title_gp = gpar(fontsize=fontsize, fontface="bold"),
    show_row_dend = T,
    column_km = 2,
    row_km = 2,
    border = T,
    column_dend_height = unit(2, "cm"),
    cluster_rows = T,
    cluster_columns =  T,
    row_dend_side = 'left',
    row_dend_reorder = T,
    row_dend_width = unit(1, "cm"),
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
         heatmap_legend_side = "bottom",
         annotation_legend_side = "bottom")
  )
  return(real_data_heatmap_plot)
}


# This function plots heatmap of simulated data feature selection ranking
# stratified by effect and correlation
plot_sim_heatmap <- function(wide_ranking_df, fontsize=12, method_palette="Paired",
                             effect_palette="Dark2", corr_palette="Pastel2",
                             heatmap_title="Ranking feature weights on simulated data\nstratified by effect and correlation") {
  # Extract relevant parameter\s
  wide_data <- wide_ranking_df %>%
    filter(is_simulated == "simulated") %>%
    mutate(
      strategy = str_extract(dataset, "(?<=_strategy-)[^_]+"),
      n = as.numeric(str_extract(dataset, "(?<=_n-)[0-9]+")),
      H = as.numeric(str_extract(dataset, "(?<=_H-)[0-9]+")),
      effect = as.numeric(str_extract(dataset, "(?<=_effect-)[0-9.]+")),
      e = as.numeric(str_extract(dataset, "(?<=_e-)[0-9]+")),
      corr = as.numeric(str_extract(dataset, "(?<=_corr-)[0-9.]+"))
    ) %>% # Now only look at those on intersim
    filter(strategy == "intersim") %>%
    # Select relevant cols
    select(-c(feature, view, dataset, is_simulated, H, e, n, strategy)) %>%
    mutate(
      effect = as.factor(effect),
      corr = as.factor(corr)
    )


  # Then get heatmap matrix, not compute correlation anymore
  heatmap_matrix <- wide_data %>%
    select(-effect, -corr) %>%
    select(order(colnames(.))) %>%
    as.matrix()
  # Match the colors

  # Create column annotations based on `effect` and `corr`
  # Assign colors to the unique values
  unique_effects <- levels(wide_data$effect)
  effect_colors <- RColorBrewer::brewer.pal(n=length(unique_effects), effect_palette) # Example color set for 3 unique values
  names(effect_colors) <- unique_effects   # Map the colors to the unique values

  unique_corr <- levels(wide_data$corr)
  corr_colors <- RColorBrewer::brewer.pal(n=length(unique_corr), corr_palette)  # Example color set for corr
  names(corr_colors) <- unique_corr   # Map the colors to the unique values



  # The annotations
  # Set a common label params
  common_label <- c("Low", "Med", "High")
  col_annotations <- rowAnnotation(
    effect = wide_data$effect,
    corr = wide_data$corr,
    col  = list(effect=effect_colors, corr=corr_colors),
    show_annotation_name = F,
    annotation_legend_param = list(
      effect = list(
        title = "Effect",
        at = c(0, 0.5, 1),
        labels = common_label
      ),
      corr = list(
        title = "Correlation",
        at = c(0, 0.5, 1),
        labels = common_label
      )
    )
  )

  # Colors for methods
  methods <- colnames(heatmap_matrix)
  method_colors <- RColorBrewer::brewer.pal(n=length(methods), method_palette)
  names(method_colors) <- methods


  row_annotations <- columnAnnotation(
    Method = colnames(heatmap_matrix),
    col = list(
      Method = method_colors
    ),
    show_annotation_name = F
  )
  # And the main col fun using sequential
  #col_fun <- viridis::viridis(n=256, option = "mako")

  col_fun = circlize::colorRamp2(seq(min(heatmap_matrix),
                                     max(heatmap_matrix),
                                     length = 3), c("blue", "#EEEEEE", "red"))

  # For clustering
  # Create the heatmap
  # This map is for labelling the cluster and row annotations
  # This is bad row title?
  sim_ht <- Heatmap(
    heatmap_matrix,
    heatmap_legend_param = list(
      title = "Ranking",
      legend_direction = "horizontal"
    ),
    #row_title = "Cluster %s | %s",
    #row_title = "Cluster %s",
    row_title_rot = 90,
    border = TRUE,
    row_km = 2,
    column_km = 2,
    # This is to manually set title
    # 18 string 2 cluster x 9 interaction level of effect and interaction

    #row_title = c("", "", "",
    #              "", "Cluster 1", "",
    #              "", "", "",
    #              "", "", "",
    #              "", "Cluster 2", "",
    #              "", "", ""),
    row_title = NULL,
    column_title = heatmap_title,
    column_title_gp = gpar(fontsize=fontsize, fontface="bold"),
    column_dend_height = unit(2.5, "cm"),
    cluster_rows = T,
    cluster_columns = TRUE,
    col = col_fun,
    show_parent_dend_line = F,
    #row_split = interaction(wide_data$effect, wide_data$corr),
    #row_split = paste("effect", wide_data$effect, "- corr:", wide_data$corr) ,
    right_annotation = col_annotations,
    top_annotation = row_annotations,
    show_row_names = F,
    show_column_names = F,
    name = "Method Values",
  )
  #return(sim_ht)
  sim_data_heatmap_plot <- grid.grabExpr(
    draw(sim_ht, merge_legends = TRUE,
         heatmap_legend_side = "bottom",
         annotation_legend_side = "bottom")
    )
  return(sim_data_heatmap_plot)
}



main <- function(input_path, output_path, data_type) {

  wide_ranking_df <- read.csv(input_path)

  if (data_type == "real") {
    out_plot <- plot_real_heatmap(wide_ranking_df, fontsize = fontsize,
                      heatmap_title = NULL)
  }

  if (data_type == "sim") {
    out_plot <- ggplot() + ggtitle("Fake plot placeholder for feature selection (sim)")
  }


  # TODO: making a placeholder now for sim data

  ggsave(output_path, plot = out_plot,
        width = width, height = height, device=device, dpi=dpi)
  message("Saved image of ", width, " x ", height, " to ", output_path)

}


opt <- docopt::docopt(doc)

# Convenient vars
input_path <- opt$input_path
output_path <- opt$output_path
data_type <- opt$data_type
# Plot params
fontsize <- 12
width <- as.numeric(opt$width)
height <- as.numeric(opt$height)
device <- opt$device
dpi <- as.numeric(opt$dpi)

# lastly call the main
main(input_path = input_path, output_path = output_path, data_type = data_type)
