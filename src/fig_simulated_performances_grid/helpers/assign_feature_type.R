assign_feature_type <- function(df, feat_col, signal_pattern="true",
                                noise_pattern="noise", signal_name="signal",
                                noise_name="noise") {
  feat_col <- rlang::ensym(feat_col)


  out <- df %>%
    mutate(
      feature_type = case_when(
        str_detect(!!feat_col, signal_pattern) ~ signal_name,
        str_detect(!!feat_col, noise_pattern) ~ noise_name,
        TRUE ~ NA_character_
      )
    )
}
