# ==============================================================================
# bulk_figure_utils.R
# Shared functions for bulk/multimodal figure panels (AUC boxplots, feature
# correlation heatmaps, pathway enrichment lines, resource complexity,
# and PanglaoDB cell-type annotation plots).
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(stringr)
  library(tidyr)
  library(ComplexHeatmap)
  library(circlize)
  library(grid)
  library(cowplot)
})

source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/common_helpers/standardize_data_funs.R"))
source(here::here("src/common_helpers/map_disease_name.R"))
source(here::here("src/common_helpers/computational_resources_utils.R"))
source(here::here("src/common_helpers//fgsea_utils.R"))


# ==============================================================================
# 1. AUC boxplot with dataset points
# ==============================================================================

#' Load and combine bulk + multimodal AUC metrics.
#'
#' @param bulk_path       Path to the bulk metrics CSV.
#' @param multimodal_path Path to the multimodal metrics CSV.
#' @param drop_datasets   Datasets to exclude.
#' @return A tibble with columns: method, dataset, auc.
load_bulk_auc_data <- function(bulk_path       = "data/raw/bulk_data/metrics.csv",
                               multimodal_path = "data/raw/multimodal_data/metrics.csv",
                               drop_datasets   = c("tcga-kipan")) {
  message("[load_bulk_auc_data] Reading bulk: ", bulk_path)
  message("[load_bulk_auc_data] Reading multimodal: ", multimodal_path)

  bulk_df <- data.table::fread(bulk_path) %>%
    dplyr::rename(method = method_name) %>%
    dplyr::select(method, dataset, auc)

  mm_df <- data.table::fread(multimodal_path) %>%
    dplyr::rename(method = method_name) %>%
    dplyr::select(method, dataset, auc)

  combined <- bind_rows(bulk_df, mm_df) %>%
    filter(!dataset %in% drop_datasets) %>%
    filter(!str_detect(method, "1")) %>%
    mutate(
      dataset = map_disease_name(tolower(dataset)),
      method  = standardize_method_names(method, "perf")
    )

  message("[load_bulk_auc_data] Loaded ", nrow(combined), " rows across ",
          n_distinct(combined$dataset), " datasets")
  return(combined)
}


#' Build an AUC boxplot with dataset-colored points and connecting lines.
#'
#' @param df        Output of [load_bulk_auc_data()].
#' @param text_size Base text size.
#' @return A ggplot object.
plot_bulk_auc_boxplot <- function(df, text_size = 48) {
  message("[plot_bulk_auc_boxplot] Building AUC boxplot...")

  df %>%
    ggplot(aes(x = forcats::fct_reorder(method, auc), y = auc)) +
    geom_hline(yintercept = 0.5, linetype = "dashed", color = "gray50") +
    geom_errorbar(stat = "boxplot", width = 0.7,
                  linewidth = 0.3, color = "gray50") +
    geom_boxplot(color = "black", fill = NA, outlier.shape = NA,
                 width = 1, linewidth = 1) +
    geom_line(aes(group = dataset, color = dataset),
              alpha = 0.8, linewidth = 0.3) +
    geom_point(aes(color = dataset), size = 8, alpha = 0.55) +
    ggsci::scale_color_d3(palette = "category20") +
    coord_flip() +
    labs(x = NULL, y = "AUC", color = "Dataset") +
    theme_bw(base_size = text_size) +
    theme(
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank()
    ) +
    guides(color = guide_legend(nrow = 4))
}


# ==============================================================================
# 2. Feature correlation heatmap
# ==============================================================================

#' Load bulk + multimodal feature selection results and compute the
#' mean Spearman correlation matrix of feature weights across datasets.
#'
#' @param bulk_path       Path to bulk feature selection CSV.
#' @param multimodal_path Path to multimodal feature selection CSV.
#' @param drop_datasets   Datasets to exclude.
#' @return A named correlation matrix.
load_bulk_feature_correlation <- function(
    bulk_path       = "data/raw/bulk_data/all_feature_selection_results.csv",
    multimodal_path = "data/raw/multimodal_data/all_feature_selection_results.csv",
    drop_datasets   = c("tcga-chol", "tcga-kipan")) {

  message("[load_bulk_feature_correlation] Reading feature selection results...")

  bulk_df <- data.table::fread(bulk_path)
  mm_df   <- data.table::fread(multimodal_path)

  combined_df <- bind_rows(bulk_df, mm_df) %>%
    dplyr::select(-feature_type, -dataset_type) %>%
    dplyr::rename(dataset = dataset_name) %>%
    standardize_view_names()

  sorted_df <- combined_df %>%
    filter(!tolower(dataset) %in% drop_datasets) %>%
    mutate(feature = case_when(
      method %in% c("mogonet", "integrao") ~ paste0(view, "_", feature),
      TRUE ~ feature
    )) %>%
    mutate(abs_coef = abs(coef))

  message("[load_bulk_feature_correlation] Computing per-dataset Spearman correlations...")
  cor_mats <- sorted_df %>%
    group_by(dataset) %>%
    group_map(~ {
      wide <- .x %>%
        ungroup() %>%
        dplyr::select(feature, method, abs_coef) %>%
        pivot_wider(names_from = method, values_from = abs_coef, values_fill = 0)
      mat <- as.matrix(wide[, -1])
      message("[load_bulk_feature_correlation]   dataset: ", .y,
              ", features: ", nrow(wide))
      cor(mat, method = "spearman")
    }, .keep = TRUE)

  mean_cor <- Reduce(`+`, cor_mats) / length(cor_mats) %>% round(3)
  rownames(mean_cor) <- standardize_method_names(rownames(mean_cor))
  colnames(mean_cor) <- standardize_method_names(colnames(mean_cor))

  message("[load_bulk_feature_correlation] Done. Matrix: ",
          nrow(mean_cor), "x", ncol(mean_cor))
  return(mean_cor)
}


#' Build a feature correlation ComplexHeatmap grob.
#'
#' @param cor_mat   Square correlation matrix from [load_bulk_feature_correlation()].
#' @param text_size Text size for labels.
#' @return A grob.
build_bulk_feature_correlation_heatmap <- function(cor_mat, text_size = 26) {
  message("[build_bulk_feature_correlation_heatmap] Building heatmap...")

  diag(cor_mat) <- NA
  col_fun <- colorRamp2(c(-0.1, 0, 0.25, 0.5),
                        c("#2166AC", "white", "#FDDBC7", "#B2182B"))

  ht <- Heatmap(
    cor_mat,
    name             = "Mean Spearman Correlation",
    col              = col_fun,
    na_col           = "grey90",
    cluster_rows     = TRUE,
    cluster_columns  = TRUE,
    row_dend_side    = "left",
    column_dend_side = "top",
    row_dend_width     = unit(2, "cm"),
    column_dend_height = unit(2, "cm"),
    row_names_gp     = gpar(fontsize = text_size),
    column_names_gp  = gpar(fontsize = text_size),
    rect_gp          = gpar(col = "white", lwd = 1),
    column_names_rot = 90,
    cell_fun = function(j, i, x, y, width, height, fill) {
      v <- cor_mat[i, j]
      if (!is.na(v)) {
        rgb_vals  <- col2rgb(fill) / 255
        luminance <- 0.299 * rgb_vals[1] + 0.587 * rgb_vals[2] +
          0.114 * rgb_vals[3]
        text_col  <- ifelse(luminance < 0.5, "white", "black")
        grid.text(sprintf("%.2f", v), x, y,
                  gp = gpar(fontsize = text_size - 4, col = text_col))
      }
    },
    heatmap_legend_param = list(
      title_gp       = gpar(fontsize = text_size, fontface = "bold"),
      labels_gp      = gpar(fontsize = text_size - 2),
      legend_height  = unit(8, "cm"),
      title_position = "lefttop-rot",
      grid_height    = unit(2, "cm"),
      grid_width     = unit(2, "cm"),
      legend_width   = unit(18, "cm")
    )
  )

  ht_grob <- grid.grabExpr(
    draw(ht, merge_legends = TRUE,
         show_heatmap_legend = FALSE,
         heatmap_legend_side = "left",
         align_heatmap_legend = "heatmap_top",
         padding = unit(c(50, 5, 5, 25), "mm"))
  )

  message("[build_bulk_feature_correlation_heatmap] Done")
  return(ht_grob)
}


# ==============================================================================
# 3. Pathway enrichment — varying FDR cutoff line plot
# ==============================================================================

#' Load and combine bulk + multimodal fgsea results with MSigDB annotations.
#'
#' @param bulk_fgsea_path       Path to bulk fgsea CSV.
#' @param multimodal_fgsea_path Path to multimodal fgsea CSV.
#' @param msigdbr_path          Path to MSigDB pathway collection RDS.
#' @return A tibble with BH-adjusted p-values and standardized method names.
load_bulk_fgsea_data <- function(
    bulk_fgsea_path       = "data/processed/bulk/bulk_msigdbr_fgsea.csv",
    multimodal_fgsea_path = "data/processed/multimodal/multimodal_msigdbr_fgsea.csv",
    msigdbr_path          = "data/processed/pathways_db/msigdbr_pathways_collection.rds") {

  message("[load_bulk_fgsea_data] Reading fgsea results...")

  msigdbr_pathways <- readRDS(msigdbr_path)
  mm_df   <- data.table::fread(multimodal_fgsea_path)
  bulk_df <- data.table::fread(bulk_fgsea_path)

  j1 <- inner_join(mm_df, msigdbr_pathways, by = c("pathway" = "gs_name"))
  j2 <- inner_join(bulk_df, msigdbr_pathways, by = c("pathway" = "gs_name"))

  msigdbr_df <- bind_rows(j1, j2) %>%
    dplyr::select(-c(gs_collection, ES, NES, size)) %>%
    dplyr::rename(old_padj = padj) %>%
    tidyr::separate_wider_delim(
      group, delim = " | ",
      names    = c("method", "dataset", "view"),
      too_many = "merge", too_few = "align_start"
    ) %>%
    group_by(method, dataset, view) %>%
    mutate(padj = p.adjust(pval, method = "BH")) %>%
    ungroup() %>%
    mutate(
      method = standardize_method_names(method),
      method = str_replace(method, "MOFA-FA", "MOFA-") %>%
        str_replace("lda", "LDA")
    )

  message("[load_bulk_fgsea_data] Loaded ", nrow(msigdbr_df), " enrichment results")
  return(msigdbr_df)
}


#' Count significant pathways across a grid of thresholds.
#'
#' @param msigdbr_df Output of [load_bulk_fgsea_data()].
#' @param thresholds Numeric vector of FDR thresholds.
#' @return A tibble with columns: threshold, method, db, n_sig.
count_bulk_sig_pathways <- function(
    msigdbr_df,
    thresholds = c(0.001, 0.005, 0.01, 0.05, 0.1, 0.2, 0.5)) {

  message("[count_bulk_sig_pathways] Counting across ",
          length(thresholds), " thresholds...")

  sig_counts <- expand.grid(
    threshold = thresholds,
    method    = unique(msigdbr_df$method),
    db        = unique(msigdbr_df$gs_collection_name)
  ) %>%
    rowwise() %>%
    mutate(
      n_sig = sum(
        msigdbr_df$padj < threshold &
          msigdbr_df$method == method &
          msigdbr_df$gs_collection_name == db,
        na.rm = TRUE
      )
    ) %>%
    ungroup()

  message("[count_bulk_sig_pathways] Done. Rows: ", nrow(sig_counts))
  return(sig_counts)
}


#' Build a line plot of significant pathways vs FDR threshold.
#'
#' @param sig_counts Output of [count_bulk_sig_pathways()].
#' @param text_size  Base text size.
#' @return A ggplot object.
plot_bulk_pathways_vary_cutoff <- function(sig_counts, text_size = 48) {
  message("[plot_bulk_pathways_vary_cutoff] Building pathway cutoff line plot...")

  sig_counts %>%
    ggplot(aes(x = n_sig, y = threshold, color = method, group = method)) +
    geom_point(size = floor(text_size / 5.2), alpha = 0.5) +
    geom_line() +
    ggrepel::geom_text_repel(
      data             = sig_counts %>% filter(threshold == 0.2),
      aes(label = method),
      direction        = "both",
      alpha            = NA,
      max.overlaps     = Inf,
      show.legend      = FALSE,
      segment.size     = 0.3,
      min.segment.length = 0,
      force            = 5,
      box.padding      = 0.75,
      nudge_x          = -0.25,
      nudge_y          = -0.05,
      arrow            = arrow(length = unit(0.015, "npc")),
      size             = floor(text_size / 4.5)
    ) +
    facet_wrap(~ db, scales = "free", nrow = 2) +
    theme_bw(text_size) +
    theme(
      legend.position    = "none",
      panel.grid.major.x = element_blank(),
      panel.grid.minor   = element_blank()
    ) +
    labs(
      x = "Number of Significant Pathways",
      y = "FDR threshold"
    ) +
    scale_color_manual(values = method_colors) +
    scale_y_reverse() +
    scale_x_log10()
}


# ==============================================================================
# 4. Resource complexity (time + memory vs dataset size)
# ==============================================================================

#' Load and summarize computational resource usage from a single data directory.
#'
#' @param data_dir Directory containing execution_trace.txt and parsed_metadata.csv.
#' @return A tibble with columns: method, dataset_name, action, dataset_size,
#'   realtime_sec, peak_rss_mb, data_type.
load_bulk_complexity <- function(data_dir) {
  if (is.null(data_dir)) {
    stop("[load_bulk_complexity] Need to supply data_dir")
  }
  message("[load_bulk_complexity] Processing: ", data_dir)

  trace_path    <- here::here(data_dir, "execution_trace.txt")
  metadata_path <- here::here(data_dir, "parsed_metadata.csv")

  trace_df <- readr::read_tsv(trace_path, col_types = readr::cols()) %>%
    dplyr::select(process, tag, realtime, peak_rss, peak_vmem, duration) %>%
    mutate(process = chop_nf_core_prefix(process)) %>%
    separate_workflow_process(process) %>%
    mutate(process = case_when(
      workflow == "CROSS_VALIDATION"  ~ str_extract(process, "[^:]+$"),
      workflow == "CALCULATE_METRICS" ~ "CALCULATE_METRICS",
      TRUE ~ process
    )) %>%
    mutate(
      realtime_sec = convert_to_seconds(realtime),
      duration_sec = convert_to_seconds(duration),
      peak_rss_mb  = convert_to_mb(peak_rss),
      peak_vmem_mb = convert_to_mb(peak_vmem)
    ) %>%
    dplyr::select(-c(realtime, peak_rss, duration, peak_vmem))

  message("[load_bulk_complexity] Reading metadata: ", metadata_path)
  metadata_df <- data.table::fread(metadata_path) %>%
    dplyr::select(dataset_name, feat_dimensions, subject_dimensions) %>%
    mutate(
      dataset_name = str_remove(dataset_name, "_processed"),
      n_subjects   = as.integer(sub(",.*", "", subject_dimensions)),
      n_features   = sapply(strsplit(feat_dimensions, ","),
                            function(x) sum(as.integer(x)))
    ) %>%
    dplyr::select(dataset_name, n_subjects, n_features) %>%
    mutate(dataset_size = n_subjects * n_features)

  known_dname <- metadata_df$dataset_name

  plot_df <- trace_df %>%
    filter(workflow %in% c("CROSS_VALIDATION", "FEATURE_SELECTION")) %>%
    filter(!str_detect(process, "MERGE")) %>%
    mutate(process = case_when(
      str_detect(process, "COOPERATIVE") ~ str_replace(
        process, "COOPERATIVE_LEARNING", "MULTIVIEW"
      ),
      TRUE ~ process
    )) %>%
    mutate(
      method = str_replace(process, "_.*", ""),
      action = str_replace(process, ".*_", "")
    ) %>%
    filter(action != "DOWNSTREAM") %>%
    mutate(process = case_when(
      str_detect(tag, "null") ~ str_c(process, "NULL", sep = "-"),
      str_detect(tag, "full") ~ str_c(process, "FULL", sep = "-"),
      TRUE ~ process
    )) %>%
    dplyr::select(workflow, process, tag, method, action,
                  realtime_sec, peak_rss_mb, peak_vmem_mb, duration_sec) %>%
    mutate(
      action       = str_replace(action, "FEATURE", "FEATURE_SELECT"),
      dataset_name = str_extract(tag, paste(known_dname, collapse = "|"))
    )

  combined_df <- left_join(metadata_df, plot_df, by = "dataset_name") %>%
    filter(action != "PREPROCESS") %>%
    mutate(action = case_when(
      action %in% c("TRAIN", "PREDICT") ~ "model_assessment",
      action == "FEATURE_SELECT"         ~ "model_selection",
      TRUE ~ action
    )) %>%
    group_by(method, dataset_name, action, tag, dataset_size) %>%
    summarize(
      realtime_sec = mean(realtime_sec),
      peak_rss_mb  = mean(peak_rss_mb),
      .groups = "drop"
    ) %>%
    group_by(method, dataset_name, action, dataset_size) %>%
    summarise(
      across(c(realtime_sec, peak_rss_mb), median),
      .groups = "drop"
    ) %>%
    mutate(data_type = basename(data_dir))

  message("[load_bulk_complexity] Done. Rows: ", nrow(combined_df))
  return(combined_df)
}


#' Standardize method names for bulk resource complexity plots.
#' @param df A tibble with a `method` column.
#' @return The tibble with display-ready method and color_label columns.
standardize_bulk_resource_methods <- function(df) {
  message("[standardize_bulk_resource_methods] Normalizing method names...")
  df %>%
    mutate(method = str_replace(method, "CARET", "CARETMULTIMODAL")) %>%
    mutate(color_label = method) %>%
    mutate(method = case_when(
      method == "CARETMULTIMODAL" ~ "caretMultimodal",
      method == "INTEGRAO"        ~ "IntegrAO",
      method == "MULTIVIEW"       ~ "Multiview",
      TRUE ~ method
    ))
}


#' Build a resource complexity line plot (runtime + memory vs dataset size).
#'
#' @param df        Combined output from [load_bulk_complexity()] for bulk +
#'   multimodal, after [standardize_bulk_resource_methods()].
#' @param text_size Base text size.
#' @return A ggplot object.
plot_bulk_resource_complexity <- function(df, text_size = 48) {
  message("[plot_bulk_resource_complexity] Building resource complexity plot...")

  method_names <- sort(unique(df$method))

  df %>%
    pivot_longer(c(realtime_sec, peak_rss_mb), names_to = "metric") %>%
    ggplot(aes(x = dataset_size, y = value,
               color = color_label, group = method)) +
    geom_line(linewidth = 1) +
    geom_point(size = floor(text_size / 5) ) +
    facet_grid(
      metric ~ action,
      scales   = "free",
      labeller = labeller(
        action = as_labeller(c(
          model_assessment = "Model Assessment",
          model_selection  = "Model Selection"
        )),
        metric = as_labeller(c(
          peak_rss_mb  = "Memory (MB)",
          realtime_sec = "Runtime (Seconds)"
        ))
      )
    ) +
    ggrepel::geom_text_repel(
      data = . %>%
        group_by(method, action, metric) %>%
        slice_max(dataset_size, n = 1),
      aes(label = method),
      direction    = "y",
      nudge_x      = 0.15,
      hjust        = 0,
      segment.size = 0.3,
      size         = floor(text_size / 5) + 2,
      show.legend  = FALSE
    ) +
    coord_cartesian(clip = "off") +
    theme_bw(base_size = text_size) +
    theme(
      panel.grid.major.x = element_blank(),
      panel.grid.minor.x = element_blank(),
      panel.grid.minor.y = element_line(linewidth = 0.3, color = "grey85"),
      legend.position    = "none"
    ) +
    scale_color_manual(values = method_family_colors, labels = method_names) +
    scale_x_log10(labels = scales::label_comma()) +
    scale_y_log10() +
    labs(x = "Dataset Size", y = NULL)
}


# ==============================================================================
# 5. PanglaoDB cell-type annotation — shared data loading
# ==============================================================================

#' Load bulk PanglaoDB fgsea results, join with pathway DB, re-adjust p-values,
#' and filter to organ-matched cell types.
#'
#' @param fgsea_path    Path to bulk panglao fgsea CSV.
#' @param panglao_path  Path to panglao pathways collection RDS.
#' @param drop_datasets Datasets to exclude.
#' @param cutoff        Adjusted p-value cutoff.
#' @return A tibble of filtered results with organ-matched cell types.
load_bulk_panglao_data <- function(
    fgsea_path    = "data/processed/bulk/bulk_panglao_fgsea.csv",
    panglao_path  = "data/processed/pathways_db/panglao_pathways_collection.rds",
    drop_datasets = c("tcga-chol", "tcga-kipan"),
    cutoff        = 0.2) {



  df <- data.table::fread(fgsea_path)
  panglao_pathways <- readRDS(panglao_path)

  bulk_panglao_df <- inner_join(df, panglao_pathways,
                                by = c("pathway" = "gs_name")) %>%
    # Then in this one, need to readjust the pval later, so
    # rename its existing padj to another name
    dplyr::rename(old_padj = padj) %>%
    tidyr::separate_wider_delim(
      group, delim = " | ",
      names    = c("method", "dataset", "view"),
      too_many = "merge", too_few = "align_start"
    ) %>%
    group_by(method, dataset, view) %>%
    mutate(padj = p.adjust(pval, method = "BH")) %>%
    ungroup()

  message("[load_bulk_panglao_data] Filtering to organ-matched cell types...")
  filtered <- bulk_panglao_df %>%
    mutate(across(where(is.character), tolower)) %>%
    filter(!dataset %in% drop_datasets) %>%
    add_manual_label() %>%
    mutate(method = standardize_method_names(method)) %>%
    filter(str_detect(organ_label, organ)) %>%
    group_by(method, dataset) %>%
    mutate(
      padj      = p.adjust(pval, method = "BH"),
      cell_type = pathway,
      method_dataset = paste(method, dataset, sep = "_")
    ) %>%
    ungroup()

  message("[load_bulk_panglao_data] Done. Rows: ", nrow(filtered))
  return(filtered)
}


#' Build a frequency bar plot of organ-matched significant cell types per method.
#'
#' @param filtered  Output of [load_bulk_panglao_data()].
#' @param cutoff    P-value cutoff for significance.
#' @param text_size Base text size.
#' @return A ggplot object.
plot_bulk_panglao_annot_bar <- function(filtered, cutoff = 0.2, text_size = 48) {
  message("[plot_bulk_panglao_annot_bar] Building annotation bar plot...")

  freq_df <- filtered %>%
    filter(!organ == "immune-system") %>%
    group_by(method, dataset, organ) %>%
    mutate(group_num = n()) %>%
    filter(padj < cutoff) %>%
    summarize(n = n(), group_num = unique(group_num), .groups = "drop") %>%
    mutate(ratio = n / group_num) %>%
    pivot_wider(names_from = organ, values_from = ratio, values_fill = 0)

  freq_df$method %>%
    table() %>%
    tibble::enframe(name = "method", value = "n") %>%
    mutate(
      color_label = str_remove(method, "-.*") %>% toupper(),
      n           = as.integer(n)
    ) %>%
    ggplot(aes(x = reorder(method, n), y = n, fill = color_label)) +
    geom_bar(stat = "identity", width = 0.7) +
    labs(x = NULL, y = "Frequency", fill = "Method") +
    scale_fill_manual(values = method_family_colors) +
    theme_bw(base_size = text_size) +
    theme(
      legend.position    = "none",
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      axis.text.y        = element_text(size = text_size)
    ) +
    coord_flip()
}


#' Build a PanglaoDB cell-type proportion ComplexHeatmap grob.
#'
#' @param filtered  Output of [load_bulk_panglao_data()].
#' @param cutoff    P-value cutoff.
#' @param text_size Text size for labels.
#' @param col_order Column (organ) ordering for the heatmap.
#' @param disease_levels Factor levels for row splitting by disease.
#' @return A grob.
build_bulk_panglao_heatmap <- function(
    filtered,
    cutoff         = 0.2,
    text_size      = 19,
    col_order      = c("Skin", "Lungs", "Brain", "Kidney", "Liver", "Thyroid"),
    disease_levels = c("Skin Cancer", "Bile Duct Cancer",
                       "Kidney Cancer (kirc)", "Kidney Cancer (kich)",
                       "Pleura Cancer", "Bladder Cancer (GSE)",
                       "Autism", "Thyroid Cancer")) {

  message("[build_bulk_panglao_heatmap] Building PanglaoDB heatmap...")

  wide_df <- filtered %>%
    filter(!organ == "immune-system") %>%
    group_by(method, dataset, organ) %>%
    mutate(group_num = n()) %>%
    filter(padj < cutoff) %>%
    summarize(n = n(), group_num = unique(group_num), .groups = "drop") %>%
    mutate(ratio = n / group_num) %>%
    pivot_wider(names_from = organ, values_from = ratio, values_fill = 0)



  annotation_table <- wide_df %>%
    mutate(
      color_label = str_remove(method, "-.*") %>% toupper(),
      color_label = if_else(color_label == "CARET_MULTIMODAL",
                            "CARET", color_label),
      dataset     = map_disease_name(tolower(dataset))
    )

  # Row annotation
  row_ha <- rowAnnotation(
    Method = factor(annotation_table$color_label,
                    levels = names(method_family_colors)),
    col = list(Method = method_family_colors),
    annotation_legend_param = list(
      Method = list(
        labels_gp = gpar(fontsize = text_size - 1.5),
        title_gp  = gpar(fontsize = text_size - 1.5, fontface = "bold"),
        nrow = 4
      )
    ),
    show_annotation_name = FALSE,
    show_legend = FALSE
  )

  # Build matrix
  plot_matrix <- wide_df %>%
    dplyr::select(-c(method, dataset, n, group_num)) %>%
    as.matrix()
  colnames(plot_matrix) <- tools::toTitleCase(colnames(plot_matrix))
  plot_matrix <- plot_matrix[, col_order]

  mapped_disease <- factor(annotation_table$dataset, levels = disease_levels)
  col_fun <- colorRamp2(c(0, 0.5, 1), c("white", "steelblue1", "blue"))

  set.seed(1)
  htmp <- Heatmap(
    plot_matrix,
    name                = "Proportion of significant cells",
    col                 = col_fun,
    right_annotation    = row_ha,
    row_split           = mapped_disease,
    cluster_rows        = TRUE,
    cluster_row_slices  = TRUE,
    cluster_columns     = FALSE,
    border              = TRUE,
    row_title_rot       = 0,
    row_gap             = unit(1, "mm"),
    column_names_rot    = 45,
    row_title_gp        = gpar(fontsize = text_size),
    column_names_gp     = gpar(fontsize = text_size),
    row_names_gp        = gpar(fontsize = text_size),
    show_row_names      = FALSE,
    show_column_dend    = FALSE,
    row_dend_width      = unit(1.5, "cm"),
    use_raster          = TRUE,
    raster_quality      = 5,
    cell_fun = function(j, i, x, y, width, height, fill) {
      value <- plot_matrix[i, j]
      if (value == 0) {
        grid.rect(x, y, width, height, gp = gpar(fill = "grey90", col = NA))
      } else {
        text_color <- get_text_color(fill)
        grid.text(sprintf("%.2f", value), x, y,
                  gp = gpar(col = text_color, fontsize = text_size))
      }
    },
    heatmap_legend_param = list(
      at               = c(0, 0.5, 1),
      labels           = c("Low", "", "High"),
      grid_height      = unit(1.25, "cm"),
      grid_width       = unit(1.25, "cm"),
      legend_width     = unit(text_size * 2, "mm"),
      labels_gp        = gpar(fontsize = text_size + 5),
      title_gp         = gpar(fontsize = text_size + 5, fontface = "bold"),
      legend_direction = "horizontal"
    )
  )

  ht_grob <- grid.grabExpr(
    draw(htmp, merge_legends = TRUE,
         show_heatmap_legend    = TRUE,
         heatmap_legend_side    = "bottom",
         annotation_legend_side = "bottom",
         #padding = unit(c(5, 5, 10, 5), "cm"))
         padding = unit(c(5, 5, 10, 5), "mm"))
  )

  message("[build_bulk_panglao_heatmap] Done")
  return(ht_grob)
}
