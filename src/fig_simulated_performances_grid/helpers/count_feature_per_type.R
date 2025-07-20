count_feature_per_type <- function(data, group_cols=c("method", "dataset", "view"),
                                   feature_col="feature_type") {
  # Convert inputs to symbols
  group_cols <- rlang::syms(c(group_cols, feature_col))
  feature_col <- rlang::ensym(feature_col)

  data %>%
    group_by(!!!group_cols) %>% # Group by the specified columns
    summarize(n = n(), .groups = "drop") %>% # Summarize counts
    pivot_wider(
      names_from = !!feature_col,
      values_from = n,
      values_fill = 0
    ) %>%
    rename_with(
    ~ paste0(.x, "_count"), # Append "_count" to those created wide column names
    # This make sure it only applies to those count columns
    -setdiff(as.character(group_cols), as.character(feature_col))
    ) %>%
    mutate(p_total = rowSums(select(., ends_with("_count"))))

}
#
# count_feature_per_type(
#   feats_df,
#   group_cols=c("method", "dataset", "view"),
#   feature_col = "feature_type"
#   )
#
#
# count_feature_per_type(feats_df, group_cols = c("dataset", "method", "view"))
