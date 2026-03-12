# ==============================================================================
# sc_figure_utils.R
# Shared functions for single-cell dataset figure panels (AUC bars, pathway
# enrichment bars, pathway heatmaps, and time-space scatter plots).
# ==============================================================================

suppressPackageStartupMessages({
  library(dplyr)
  library(ggplot2)
  library(stringr)
  library(tidyr)
  library(forcats)
  library(ComplexHeatmap)
  library(grid)
})

source(here::here("src/common_helpers/plot_utils.R"))
source(here::here("src/common_helpers/save_plot_both.R"))
source(here::here("src/common_helpers/standardize_data_funs.R"))
source(here::here("src/common_helpers/computational_resources_utils.R"))


# ==============================================================================
# Theme helpers
# ==============================================================================

#' Ribbon-style title using ggtext.
sc_ribbon_title <- function(base_size = 8, bg_color = "#2c3e50") {
  theme(
    plot.title = ggtext::element_textbox_simple(
      size    = base_size + 1,
      face    = "bold",
      color   = "white",
      fill    = bg_color,
      padding = margin(5, 5, 5, 5),
      margin  = margin(0, 0, 2, 0),
      halign  = 0.5,
      width   = unit(1, "npc"),
      r       = unit(0, "pt")
    )
  )
}

#' Theme for computational resource panels.
sc_resource_panel_theme <- function(text_size) {
  theme(
    legend.title       = element_text(size = text_size + 2),
    legend.text        = element_text(size = text_size),
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.background   = element_rect(fill = "grey95", color = "grey70"),
    panel.spacing.y    = unit(1, "lines"),
    strip.text.x       = element_text(size = text_size + 2, face = "bold"),
    strip.text.y       = element_text(size = text_size)
  )
}


# ==============================================================================
# 1. AUC bar plot
# ==============================================================================

#' Load and prepare AUC metrics for a single dataset.
#'
#' @param metrics_path Path to the metrics CSV.
#' @param dataset_filter Dataset name to filter on (NULL to keep all rows,
#'   e.g. for HTX which has only one dataset).
#' @return A tibble with columns: method, dataset, auc, color_label.
load_sc_auc_data <- function(metrics_path, dataset_filter = NULL) {
  message("[load_sc_auc_data] Reading: ", metrics_path)

  df <- data.table::fread(metrics_path) %>%
    dplyr::rename(method = method_name)

  if (!is.null(dataset_filter)) {
    df <- df %>% filter(dataset == dataset_filter)
  }

  df <- df %>%
    mutate(
      dataset = str_replace_all(dataset, "_", " + ") %>% tools::toTitleCase()
    ) %>%
    dplyr::select(method, dataset, auc) %>%
    filter(!str_detect(method, "-1")) %>%
    mutate(
      method      = standardize_method_names(method, "perf"),
      color_label = str_remove(method, "-.*") %>% toupper()
    ) %>%
    mutate(color_label = if_else(str_detect(color_label, "MOFA"),
                                 "MOFA", color_label))

  message("[load_sc_auc_data] Loaded ", nrow(df), " rows")
  return(df)
}


#' Create an AUC bar plot panel.
#'
#' @param df         Output of [load_sc_auc_data()].
#' @param title      Ribbon title text (e.g. "sc-COVID multiomics").
#' @param text_size  Base text size for theming.
#' @return A ggplot object.
plot_sc_auc_bar <- function(df, title, text_size = 48) {
  message("[plot_sc_auc_bar] Building AUC bar plot: ", title)

  df %>%
    ggplot(aes(x = reorder(method, auc), y = auc, fill = color_label)) +
    geom_bar(stat = "identity", width = 0.7) +
    geom_hline(yintercept = 0.5, linetype = "dashed",
               linewidth = 1.5, color = "red") +
    scale_y_continuous(expand = expansion(mult = c(0, 0.12))) +
    scale_fill_manual(values = method_family_colors) +
    coord_flip() +
    theme_bw(base_size = text_size) +
    theme(
      plot.title         = element_text(hjust = 0.5),
      strip.background   = element_rect(fill = "grey95", color = "grey70"),
      strip.text         = element_text(face = "bold", size = 11),
      panel.grid.major.y = element_blank(),
      panel.grid.minor   = element_blank(),
      legend.position    = "none"
    ) +
    sc_ribbon_title(text_size) +
    ggtitle(title) +
    labs(x = NULL, y = "AUC")
}


# ==============================================================================
# 2. Pathway enrichment data loading (shared by heatmap + bar)
# ==============================================================================

#' Load fgsea results, join with MSigDB, filter to Reactome, re-adjust p-values.
#'
#' @param fgsea_path      Path to the fgsea CSV.
#' @param msigdbr_path    Path to the MSigDB pathway collection RDS.
#' @param group_columns   Column names from separate_wider_delim on the `group`
#'   field (varies by dataset: covid_multiomics uses method/dataset/view/celltype,
#'   htx uses method/dataset/celltype, etc.).
#' @param dataset_filter  Optional dataset name to filter on.
#' @param padj_group_vars Grouping variables for BH p-value re-adjustment.
#' @return A tibble with cleaned pathway names and standardized method names.
load_sc_fgsea_data <- function(fgsea_path,
                               msigdbr_path    = "data/processed/pathways_db/msigdbr_pathways_collection.rds",
                               group_columns   = c("method", "dataset", "view", "celltype"),
                               dataset_filter  = NULL,
                               padj_group_vars = NULL) {
  message("[load_sc_fgsea_data] Reading: ", fgsea_path)

  msigdbr_pathways <- readRDS(msigdbr_path)
  raw_df <- data.table::fread(fgsea_path)

  df <- inner_join(raw_df, msigdbr_pathways,
                   by = c("pathway" = "gs_name")) %>%
    filter(gs_collection_name == "Reactome Pathways") %>%
    dplyr::rename(old_padj = padj) %>%
    dplyr::select(-gs_collection) %>%
    tidyr::separate_wider_delim(
      group, delim = " | ",
      names    = group_columns,
      too_many = "merge",
      too_few  = "align_start"
    )

  if (!is.null(dataset_filter)) {
    df <- df %>% filter(dataset == dataset_filter)
  }

  # Set default grouping for BH adjustment if not specified

  if (is.null(padj_group_vars)) {
    padj_group_vars <- intersect(
      c("method", "dataset", "view", "organ", "celltype"),
      colnames(df)
    )
  }

  df <- df %>%
    group_by(across(all_of(padj_group_vars))) %>%
    mutate(padj = p.adjust(pval, method = "BH")) %>%
    ungroup() %>%
    mutate(
      pathway = pathway %>%
        str_remove("^REACTOME_") %>%
        str_replace_all("_", " ") %>%
        str_to_title()
    ) %>%
    mutate(method = standardize_method_names(method))

  message("[load_sc_fgsea_data] Loaded ", nrow(df), " enrichment results")
  return(df)
}


# ==============================================================================
# 3. Significant pathways bar plot
# ==============================================================================

#' Count significant pathways at a set of thresholds.
#'
#' @param df            Output of [load_sc_fgsea_data()].
#' @param facet_var     Column name to use as the secondary facet (e.g. "view"
#'   or "organ"). NULL if no secondary facet is needed.
#' @param threshold_val The FDR threshold to display (default 0.2).
#' @return A tibble of counts.
count_sc_sig_pathways <- function(df,
                                  facet_var      = NULL,
                                  threshold_val  = 0.2) {
  message("[count_sc_sig_pathways] Counting significant pathways at FDR < ",
          threshold_val)

  group_cols <- c("celltype", "method", "threshold")
  select_cols <- c("method", "celltype", "padj")

  if (!is.null(facet_var)) {
    group_cols  <- c(group_cols, facet_var)
    select_cols <- c(select_cols, facet_var)
  }

  thresholds <- c(0.001, 0.005, 0.01, 0.05, 0.1, 0.2, 0.5)

  sig_counts <- df %>%
    dplyr::select(all_of(select_cols)) %>%
    crossing(threshold = thresholds) %>%
    group_by(across(all_of(group_cols))) %>%
    summarise(n_sig = sum(padj < threshold, na.rm = TRUE),
              .groups = "drop") %>%
    filter(threshold %in% threshold_val) %>%
    mutate(threshold = paste0("FDR < ", threshold * 100, "%"))

  return(sig_counts)
}


#' Build a significant pathways bar plot.
#'
#' @param sig_counts  Output of [count_sc_sig_pathways()].
#' @param facet_var   Column for row faceting (e.g. "view", "organ", "dataset").
#'   NULL for no row facet.
#' @param reorder_within Whether to use tidytext::reorder_within for per-facet
#'   ordering (needed when methods differ across facet panels).
#' @param text_size   Base text size.
#' @return A ggplot object.
plot_sc_sig_pathways_bar <- function(sig_counts,
                                     facet_var      = NULL,
                                     reorder_within = FALSE,
                                     text_size      = 48) {
  message("[plot_sc_sig_pathways_bar] Building pathway bar plot...")

  if (reorder_within && !is.null(facet_var)) {
    p <- sig_counts %>%
      ggplot(aes(
        x    = n_sig,
        y    = tidytext::reorder_within(method, n_sig, .data[[facet_var]]),
        fill = celltype
      )) +
      tidytext::scale_y_reordered()
  } else {
    p <- sig_counts %>%
      ggplot(aes(x = n_sig, y = reorder(method, n_sig), fill = celltype))
  }

  p <- p +
    geom_bar(stat = "identity") +
    scale_x_continuous(expand = expansion(c(0, 0.12))) +
    theme_bw(text_size) +
    theme(
      panel.grid.major.y = element_blank(),
      legend.position    = "none"
    ) +
    labs(x = NULL, y = NULL)

  # Add facet if specified
  if (!is.null(facet_var)) {
    p <- p + facet_grid(reformulate("threshold", facet_var), scales = "free")
  } else {
    p <- p + facet_grid(~ threshold)
  }

  return(p)
}


# ==============================================================================
# 4. Pathway recovery heatmap
# ==============================================================================

#' Classify pathways by domain relevance.
#'
#' @param df       Output of [load_sc_fgsea_data()].
#' @param patterns Regex pattern string for pathway matching.
#' @param type_label Label for matching pathways (e.g. "direct_sarscov2",
#'   "allograft_rejection_mhc").
#' @return The df with added `type` column.
classify_sc_pathways <- function(df, patterns, type_label) {
  message("[classify_sc_pathways] Classifying pathways as '", type_label, "'")
  df %>%
    mutate(
      pathway = as.character(pathway),
      type    = if_else(
        str_detect(pathway, regex(patterns, ignore_case = TRUE)),
        type_label,
        "other"
      )
    )
}


#' Build a ComplexHeatmap grob for pathway recovery.
#'
#' @param df           Output of [classify_sc_pathways()].
#' @param type_label   Which type to keep in the heatmap.
#' @param padj_cutoff  Adjusted p-value cutoff (default 0.2).
#' @param text_size    Text size for labels and legends.
#' @param col_wrap     Character width for wrapping column names.
#' @param heatmap_col  Optional named color vector for the heatmap cells
#'   (e.g. c("0" = "blue", "1" = "red") for binary). NULL uses default.
#' @param heatmap_name Legend title for the heatmap values.
#' @param heatmap_legend_extra Extra params for heatmap_legend_param (list).
#' @param padding_mm   Bottom padding in mm for the drawn heatmap.
#' @return A grob.
build_sc_pathway_heatmap <- function(df,
                                     type_label,
                                     padj_cutoff          = 0.2,
                                     text_size            = 20,
                                     col_wrap             = 24,
                                     heatmap_col          = NULL,
                                     heatmap_name         = "n_sig",
                                     heatmap_legend_extra = list(),
                                     padding_mm           = 20) {
  message("[build_sc_pathway_heatmap] Building heatmap for type='", type_label, "'")

  # Build wide matrix

  wide_df <- df %>%
    filter(padj < padj_cutoff, type == type_label) %>%
    transmute(
      method_celltype = paste(method, celltype, sep = " | "),
      pathway         = pathway
    ) %>%
    dplyr::count(method_celltype, pathway, name = "n") %>%
    pivot_wider(names_from = pathway, values_from = n, values_fill = 0)

  mat <- wide_df %>% dplyr::select(-method_celltype) %>% as.matrix()

  # Extract annotation vectors
  celltypes_in  <- str_remove(wide_df$method_celltype, ".*\\|") %>% str_trim()
  methods_in    <- str_replace(wide_df$method_celltype, "\\s*\\|.*", "")
  present_ct    <- sort(unique(celltypes_in))
  present_meth  <- sort(unique(methods_in))

  # Celltype colors
  unique_ct     <- sort(unique(df$celltype))
  ct_cols       <- scales::hue_pal()(length(unique_ct))
  names(ct_cols) <- unique_ct

  # Legend gpar helper
  legend_params <- function(at_vals, label_vals) {
    list(
      at        = at_vals,
      labels    = label_vals,
      title_gp  = gpar(fontsize = text_size, fontface = "bold"),
      labels_gp = gpar(fontsize = text_size - 2),
      legend_height = unit(3, "cm")
    )
  }

  # Row annotation
  row_ha <- rowAnnotation(
    Celltype = factor(celltypes_in, levels = names(ct_cols)),
    Method   = factor(methods_in, levels = names(method_colors)),
    simple_anno_size = unit(18, "mm"),
    col = list(Method = method_colors, Celltype = ct_cols),
    annotation_legend_param = list(
      Celltype = legend_params(present_ct, present_ct),
      Method   = legend_params(present_meth, present_meth)
    ),
    show_legend        = c(Celltype = TRUE, Method = TRUE),
    annotation_name_gp = gpar(fontsize = text_size, fontface = "bold")
  )

  # Wrap column names
  colnames(mat) <- str_wrap(colnames(mat), col_wrap)

  # Heatmap arguments
  ht_args <- list(
    mat,
    name              = heatmap_name,
    left_annotation   = row_ha,
    row_title         = NULL,
    column_title      = "Pathway",
    column_title_gp   = gpar(fontsize = text_size, fontface = "bold"),
    cluster_rows      = FALSE,
    split             = methods_in,
    column_names_gp   = gpar(fontsize = text_size),
    heatmap_legend_param = c(
      list(
        title_gp      = gpar(fontsize = text_size, fontface = "bold"),
        labels_gp     = gpar(fontsize = text_size - 2),
        legend_height = unit(3, "cm")
      ),
      heatmap_legend_extra
    )
  )
  if (!is.null(heatmap_col)) ht_args$col <- heatmap_col

  ht <- do.call(Heatmap, ht_args)

  # Draw and grab as grob
  ht_grob <- grid.grabExpr(
    draw(ht,
         merge_legends       = TRUE,
         heatmap_legend_side = "left",
         show_heatmap_legend = TRUE,
         padding             = unit(c(padding_mm, 0, 0, 0), "mm"))
  )

  message("[build_sc_pathway_heatmap] Done")
  return(ht_grob)
}


# ==============================================================================
# 5. Time-space scatter plot
# ==============================================================================

#' Load and process a Nextflow execution trace for sc datasets.
#'
#' @param trace_path    Path to execution_trace.txt.
#' @param metadata_path Path to parsed_metadata.csv.
#' @param dataset_pattern Regex to filter dataset_name (e.g. "multiomics",
#'   "organ", "htx").
#' @return A summarized tibble with realtime_sec and peak_rss_mb per
#'   method/dataset/action.
load_sc_time_space_data <- function(trace_path,
                                    metadata_path,
                                    dataset_pattern) {
  message("[load_sc_time_space_data] Reading trace: ", trace_path)

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

  message("[load_sc_time_space_data] Reading metadata: ", metadata_path)
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

  message("[load_sc_time_space_data] Preparing plot data, filtering to '",
          dataset_pattern, "'...")

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
    filter(str_detect(tolower(dataset_name), dataset_pattern)) %>%
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
    )

  message("[load_sc_time_space_data] Done. Rows: ", nrow(combined_df))
  return(combined_df)
}


#' Standardize method names for the time-space scatter plot.
#' @param df A tibble with a `method` column in uppercase.
#' @return The tibble with display-ready method and color_label columns.
standardize_sc_time_space_methods <- function(df) {
  df %>%
    mutate(method = str_replace(method, "CARET", "CARETMULTIMODAL")) %>%
    mutate(color_label = method) %>%
    mutate(method = case_when(
      method == "CARETMULTIMODAL" ~ "caretMultimodal",
      method == "INTEGRAO"        ~ "IntegrAO",
      method == "MULTIVIEW"       ~ "Multiview",
      TRUE ~ method
    )) %>%
    mutate(method = fct_reorder(method, realtime_sec))
}


#' Build a time-space scatter plot.
#'
#' @param df        Output of [load_sc_time_space_data()] after
#'   [standardize_sc_time_space_methods()].
#' @param text_size Base text size.
#' @param y_breaks  Breaks for the log10 y-axis.
#' @return A ggplot object.
plot_sc_time_space <- function(df,
                               text_size = 48,
                               y_breaks  = c(300, 500, 700, 1000, 1500)) {
  message("[plot_sc_time_space] Building time-space scatter plot...")
  # Use point size = 8 and size of geom_text_repel = 10 for generic size of 48


  df %>%
    ggplot(aes(x = realtime_sec, y = peak_rss_mb,
               color = color_label, label = method)) +
    geom_point(size = floor(text_size / 6)) +
    scale_y_log10(labels = scales::label_comma(), breaks = y_breaks) +
    scale_x_log10(labels = scales::label_comma()) +
    facet_wrap(
      ~ action,
      labeller = as_labeller(c(
        model_assessment = "Model Assessment",
        model_selection  = "Model Selection"
      )),
      nrow = 2
    ) +
    ggrepel::geom_text_repel(
      data=df,
      show.legend = FALSE, max.overlaps = Inf,
      min.segment.length = 0, size = floor(text_size / 6) +2
    ) +
    scale_color_manual(values = method_family_colors) +
    theme_bw(text_size) +
    theme(
      legend.position = "none",
      legend.box      = "vertical"
    ) +
    labs(x = "Runtime (Seconds)", y = "Peak Memory (MB)")
}
