library(dplyr)
library(ggplot2)


wrangle_sim_data <- function(df) {
  wrangle_df <- df %>%
    dplyr::rename(method = method_name) %>%
    ungroup() %>%
    dplyr::select(
      method, dataset,
      auc, f1_score
    )

  return(wrangle_df)
}


wrangle_sim_feat_selection <- function(df) {
  df %>%
    dtplyr::lazy_dt() %>%  # Translates dplyr to fast data.table
    dplyr::rename(dataset = dataset_name) %>%

    # Fix mogonet feature naming
    mutate(feature = case_when(
      str_detect(method, "mogonet") ~ paste(view, feature, sep = "_"),
      TRUE ~ feature
    )) %>%
    # Append view-related info to method
    mutate(method = case_when(
      str_detect(view, "Factor") ~ paste0(method, "-", str_extract(view, "Factor.*")),
      str_detect(view, "ncomp")  ~ paste0(method, "_", str_extract(view, "ncomp.*")),
      TRUE ~ method
    )) %>%
    # Final renaming of method
    mutate(method = case_when(
      str_detect(method, "gcca")        ~ paste0(method, " + lda"),
      str_detect(method, "mofa")        ~ paste0(method, " + glmnet"),
      str_detect(method, "cooperative") ~ "multiview",
      TRUE ~ method
    )) %>%
    as_tibble()  # Materialize result (computed now)
}

clean_feat_sim <- function(feat_result_df) {
  all_counts_df <- feat_result_df %>%
    dplyr::count(method, dataset, view, feature_type, name = "n") %>%
    pivot_wider(names_from = feature_type, values_from = n, values_fill = 0) %>%
    dplyr::rename(n_real = real, n_noise = noise)

  # Step 2: Join this to feat_result_df
  feat_with_counts <- feat_result_df %>%
    left_join(all_counts_df, by = c("method", "dataset", "view")) %>%
    arrange(method, dataset, view, desc(abs(coef))) %>%
    group_by(method, dataset, view) %>%
    mutate(rank = row_number()) %>%
    mutate(category = case_when(
      rank <= dplyr::first(n_real) ~ "top_counts",
      rank > n() - dplyr::first(n_noise) ~ "bottom_counts",
      TRUE ~ NA_character_
    )) %>%
    ungroup() %>%
    filter(!is.na(category)) %>%
    dplyr::count(method, dataset, view, feature_type, category, name = "n_selected")

  # Step 3: Compute confusion matrix components
  flat_bin_metric_df <- feat_with_counts %>%
    pivot_wider(
      names_from = c(category, feature_type),
      values_from = n_selected,
      values_fill = 0
    ) %>%
    transmute(
      method, dataset, view,
      TP = top_counts_real,
      FP = top_counts_noise,
      FN = bottom_counts_real,
      TN = bottom_counts_noise,
      N = TP + FP + FN + TN
    )

  # Step 4: Calculate metrics and return it
  flat_bin_metric_df %>%
    group_by(method, dataset, view) %>%
    summarize(
      sensitivity = TP / (TP + FN),
      specificity = TN / (TN + FP),
      precision = TP / (TP + FP),
      accuracy = (TP + TN) / N
    ) %>%
    retrieve_sim_params()
}

# ==============================================================================
# Plotting stuff

# Use this function to create the individual panel
create_panel_plot <- function(data, metric_filter, metric_label, y_label_expr, text_size) {
  data |>
    filter(metric == metric_filter) |>
    mutate(metric = metric_label) |>
    ggplot(aes(x = method, y = value, fill = corr)) +
    # Original padding 0.4
    geom_bar(stat = "identity", position = position_dodge2(padding = 0.6), alpha=0.7) +
    ylab(y_label_expr) +
    theme_bw(base_size = text_size) +
    facet_grid(metric ~ signal) +
    # Calls on another theme in plot_utils
    custom_theme_for_sim_plot(text_size) +
    #scale_x_discrete(labels = function(x) stringr::str_wrap(x, width = 12)) +
    scale_y_continuous(expand = expansion(mult = c(0, 0.07))) +
    scale_fill_manual(
      values = c("0" = "#C6DBEF", "0.5" = "#6BAED6", "1" = "#2171B5"),
      labels = c("0" = "Low", "0.5" = "Medium", "1" = "High")
    ) +
    labs(fill="Correlation") +
    guides(
      fill = guide_legend(
        title.position = "left",
        label.position = "bottom",
        direction = "horizontal"
      )
    ) +
    # This is remove extra space after final arrangement
    theme(plot.margin = margin(6, 0, 0, 6),
          axis.text.x = element_text(angle=45, vjust=1))
}

resource_panel_theme <- function(text_size) {
  # Remove the vertical lines in x-axis
  theme(
    legend.title = element_text(size = text_size + 2),  # Change title text size
    legend.text = element_text(size = text_size),    # Change label text size
    panel.grid.major.x = element_blank(),
    panel.grid.minor.x = element_blank(),
    strip.background = element_rect(fill = "grey95", color = "grey70"),
    panel.spacing.y = unit(1, "lines"),     # Increase vertical spacing
    strip.text.x = element_text(size=text_size + 2, face = "bold"),
    strip.text.y = element_text(size=text_size)
    #strip.placement = "outside"             # Optional: keeps strip outside the panel
  )
}


# Additional theme to empty legend and ticks
theme_empty_legend_ticks <- function() {
  theme(
    legend.position="none",
    axis.text.x = element_blank(),
    axis.ticks.x = element_blank(),
    axis.title.x = element_blank(),
  )
}

# Additional theme to remove the ribbon text from grid.x
theme_empty_ribbon <- function() {
  theme(
    strip.background.x = element_blank(),
    strip.text.x = element_blank()
  )
}
