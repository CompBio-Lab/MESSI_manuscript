library(dplyr)

get_counts <- function(df, by) {
  df %>%
    group_by( {{ by }} ) %>%
    summarize(n = n())
}

get_var_counts <- function(feats_df, all_counts_df,
                           group_col,
                           type=c("top", "bottom"),
                           noise_var_label = "noise"
) {
  arranged_df <- feats_df %>%
    arrange(desc(abs( coef )))


  if (type == "top") {
    num_var <- all_counts_df %>%
      filter({{ group_col }} != noise_var_label) %>% pull(n)
    df <- arranged_df %>%
      slice_head(n=num_var)
  }

  if (type == "bottom") {
    num_var <- all_counts_df %>%
      filter({{ group_col }} == noise_var_label) %>% pull(n)
    df <- arranged_df %>%
      slice_tail(n=num_var)

  }
  df %>%
    get_counts(by = {{ group_col }} ) %>%
    mutate(category = paste0(type, "_", "counts"))
}


get_fs_stats <- function(top_bottom_counts,
                         top_identifier="top_counts",
                         bottom_identifier="bottom_counts") {
  top_bottom_counts %>%
    summarise(
      TP = sum(n_selected[category == top_identifier & feature_type == "real"], na.rm = TRUE),
      FP = sum(n_selected[category == top_identifier & feature_type == "noise"], na.rm = TRUE),
      FN = sum(n_selected[category == bottom_identifier & feature_type == "real"], na.rm = TRUE),
      TN = sum(n_selected[category == bottom_identifier & feature_type == "noise"], na.rm = TRUE),
      N = sum(TP, TN, FP, FN),
      .groups = "drop"
    )
}

