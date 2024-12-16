new_p_data <- feats_df %>%
  group_by(method, dataset) %>%
  arrange(desc(abs(coef)), .by_group=TRUE) %>%
  group_map(~ {
    matched <- all_counts_df %>%
      filter(method == .y$method, dataset == .y$dataset)

    top_num <- matched %>% pull(true_count)
    bottom_num <- matched %>% pull(noise_count)

    # If there are no "truth" or "noise" features, set top_num or bottom_num to 0
    if (length(top_num) == 0) top_num <- 0
    if (length(bottom_num) == 0) bottom_num <- 0

    # Slicing the top features (only if there are "truth" features)
    if (top_num > 0) {
      top_sliced <- slice_head(.x, n = top_num) %>%
        count(feature_type, name = "n_selected") %>%
        mutate(category = "top_truth")
      #mutate(category = "top_truth", top_num = top_num)
    } else {
      top_sliced <- data.frame(feature_type = character(0), n_selected = integer(0), category = character(0), top_num = integer(0))
    }

    # Slicing the bottom features (only if there are "noise" features)
    if (bottom_num > 0) {
      bottom_sliced <- slice_tail(.x, n = bottom_num) %>%
        count(feature_type, name = "n_selected") %>%
        mutate(category = "bottom_noise")
      #mutate(category = "bottom_noise", bottom_num = bottom_num)
    } else {
      bottom_sliced <- data.frame(feature_type = character(0), n_selected = integer(0), category = character(0), bottom_num = integer(0))
    }

    binded <- bind_rows(top_sliced, bottom_sliced)
    output <- bind_cols(.y, binded)
    return(output)
  }) %>%
  bind_rows() %>%
  ungroup() %>%
  rename(n=n_selected) %>%
  get_fs_stats(top_identifier = "top_truth",
               bottom_identifier = "bottom_noise") %>%
  group_by(method, dataset) %>%
  summarize(
    sensitivity = TP / (TP + FN),
    specificity = TN / (TN + FP),
    precision = TP / (TP + FP),
    accuracy = (TP + TN) / N
  )  %>%
  ungroup() %>%
  {.}
