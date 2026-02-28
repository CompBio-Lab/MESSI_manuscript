# Fig 1A AUC Heatmap of Predictive Performance
source(here::here("plot_scripts/performance_evaluation_utils.R"))
source(here::here("src/common_helpers/map_disease_name.R"))
source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))

# Load libraries

library(dplyr)
library(ComplexHeatmap)
library(data.table)
# Function to determine text color based on background color
get_text_color <- function(fill_color) {
  rgb <- col2rgb(fill_color)
  luminance <- (0.299 * rgb[1] + 0.587 * rgb[2] + 0.114 * rgb[3]) / 255
  ifelse(luminance < 0.5, "white", "black")
}


clean_real <- function(wr_df, metadata_path) {
  auc_matrix <- wr_df %>%
    dplyr::select(method, dataset, auc) %>%
    pivot_wider(names_from = dataset, values_from = auc) %>%
    arrange(method) %>%
    dplyr::select(order(colnames(.))) %>%
    tibble::column_to_rownames(var="method") %>%
    as.matrix()

  rank_matrix <- wr_df %>%
    dplyr::select(method, dataset, ranking) %>%
    pivot_wider(names_from = dataset, values_from = ranking) %>%
    arrange(method) %>%
    dplyr::select(order(colnames(.))) %>%
    tibble::column_to_rownames(var="method") %>%
    as.matrix()

  annotation_df <- wr_df %>%
    dplyr::select(dataset, disease) %>%
    distinct()

  # --- Prepare positive proportion data ---
  metadata_df <- read.csv(metadata_path)

  positive_prop <- metadata_df |>
    dplyr::mutate(dataset_name = tolower(stringr::str_remove(dataset_name, "_processed"))) |>
    dplyr::select(dataset_name, positive_prop) |>
    dplyr::filter(dataset_name %in% colnames(auc_matrix)) |>
    tibble::deframe()  # named vector directly

  return(list(auc_matrix=auc_matrix, rank_matrix=rank_matrix, annotation_df=annotation_df,
              positive_prop = positive_prop))
}

bulk_auc_preprocess_main <- function(input_path="data/raw/bulk_data/metrics.csv",
                                     metadata_path="data/raw/bulk_data/parsed_metadata.csv") {

  # Datasets to exclude
  exclude_data <- c("tcga-chol", "tcga-kipan")
  # First do common wrangling on the input data

  wrangle_df <- fread(input_path) %>%
    wrangle_bulk_data() %>%
    # Filter the unwanted data
    filter(!(tolower(dataset) %in% exclude_data)) %>%
    # For performance eval, ncomp could use the latest ncomp as it includes
    # previous ncomp
    filter(!str_detect(tolower(method), "ncomp-1")) %>%
    # TODO: this a fix for real data only
    mutate(
      method = str_remove(method, "_ncomp-2"),
      dataset = str_to_lower(dataset)
    ) %>%
    mutate(disease = map_disease_name(dataset)) %>%
    as_tibble()

  # Handle data type-specific processing
  clean_rds <- clean_real(wrangle_df, metadata_path)
  return(clean_rds)
}



plot_fig1_real <- function(
    input_data,
    text_size      = 12,
    method_palette = "Paired",
    heatmap_title  = "Mean AUC (5-fold CV) ranking in real datasets"
) {
  # --- Input validation ---
  if (!is.list(input_data)) stop("input_data must be a list")
  required_keys <- c("auc_matrix", "rank_matrix", "annotation_df")
  if (!all(required_keys %in% names(input_data))) {
    stop("input_data must contain: 'auc_matrix', 'rank_matrix', and 'annotation_df'")
  }

  auc_matrix    <- input_data$auc_matrix
  annotation_df <- input_data$annotation_df
  positive_prop <- input_data$positive_prop



  # --- Rename columns from dataset ID to disease name ---
  dataset_to_disease  <- setNames(annotation_df$disease, annotation_df$dataset)
  positive_prop        <- positive_prop[colnames(auc_matrix)]
  colnames(auc_matrix) <- dataset_to_disease[colnames(auc_matrix)]


  # --- Color setup ---
  methods       <- rownames(auc_matrix)
  method_colors <- setNames(
    RColorBrewer::brewer.pal(n = length(methods), method_palette),
    methods
  )

  auc_range <- c(
    round(min(auc_matrix), 1),
    round(median(auc_matrix), 1),
    ceiling(max(auc_matrix))
  )

  max_dev <- max(abs(auc_matrix - 0.5))

  #col_fun <- viridis::mako(n = 256)
  col_fun <- circlize::colorRamp2(
    c(0.5 - max_dev, 0.5, 0.5 + max_dev),
    c("#3B8BC2", "#F7F7F7", "#D55E00")
  )
  q_vals <- quantile(positive_prop, probs = c(0, 0.25, 0.5, 0.75, 1), na.rm = TRUE)
  # --- Annotations ---
  prop_ha <- HeatmapAnnotation(
    positive_prop = positive_prop,
    col = list(
      positive_prop = circlize::colorRamp2(
        q_vals,
        c("#F0FAF9", "#A2D9C9", "#66C2A4", "#1B9E77", "#00441B")
      )
    ),
    show_annotation_name = FALSE,
    annotation_legend_param = list(
      positive_prop = list(
        title = "Positive proportion",
        direction = "horizontal",
        grid_height = unit(2, "mm"),
        grid_width = unit(2, "mm"),
        labels_gp = gpar(fontsize = text_size - 1.5),
        title_gp = gpar(fontsize=  text_size - 1.5, fontface="bold")
      )
    )
  )

  # --- Heatmap ---
  ht <- Heatmap(
    #t(auc_matrix), # This shows dataset in row, method in column
    auc_matrix,
    col          = col_fun,
    border       = TRUE,
    column_title = heatmap_title,
    column_title_gp = gpar(fontsize = text_size, fontface = "bold"),

    # Names
    row_names_rot  = 0,
    column_names_rot = ,
    row_names_gp   = gpar(fontsize = text_size),
    column_names_gp = gpar(fontsize = text_size),
    show_row_names  = TRUE,
    show_column_names = TRUE,

    # Clustering
    cluster_rows          = TRUE,
    column_dend_reorder   = TRUE,
    row_dend_reorder      = TRUE,
    show_row_dend         = FALSE,
    show_parent_dend_line = FALSE,
    column_dend_height    = unit(0.75, "cm"),
    row_title             = NULL,

    # Annotations
    top_annotation = prop_ha,

    # Cell labels with adaptive text color
    cell_fun = function(j, i, x, y, width, height, fill) {
      grid.text(
        #sprintf("%.3f", t(auc_matrix)[i, j]),
        sprintf("%.3f", auc_matrix[i,j]),
        x, y,
        gp = gpar(col = get_text_color(fill), fontsize = text_size - 0.5)
      )
    },

    # Legend
    heatmap_legend_param = list(
      title          = "Mean AUC",
      #title_position = "leftcenter",
      at             = auc_range,
      labels         = c("Low", "", "High"),
      labels_gp = gpar(fontsize = text_size - 1.5),
      title_gp = gpar(fontsize=  text_size - 1.5, fontface="bold"),
      grid_height    = unit(2, "mm"),
      grid_width     = unit(2, "mm"),
      legend_width   = unit(30, "mm"),
      legend_direction = "horizontal"
    )
  )

  # --- Draw and return ---
  grid.grabExpr(
    draw(ht, merge_legends = TRUE,
         heatmap_legend_side = "bottom",
         annotation_legend_side = "bottom",
         align_heatmap_legend = "global_center")
  )
}

simple=F # Change to F to run ALL
if (simple) {
  message("\nUsing fast run data of all methods + 2 datasets")
  input_path <- "data/raw/fast_run/metrics.csv"
  output_path <- "data/raw/fast_run/parsed_metadata.csv"
} else {
  message("\nUsing bulk data of all methods and all datasets")
  input_path <- "data/raw/bulk_data/metrics.csv"
  output_path <- "data/raw/bulk_data/parsed_metadata.csv"
}


input_data <- bulk_auc_preprocess_main(input_path, output_path)

out_plot <- plot_fig1_real(
  input_data = input_data,
  text_size = 6,
  method_palette = "Paired",
  heatmap_title = NULL
)



output_png_path <- "results/bulk/fig4b_bulk_auc_performance_heatmap.png"
save_plot_both(out_plot, output_png_path, width=12, height=8)
message("\nDone fig4B bulk auc performance, see fig at: ", output_png_path)
