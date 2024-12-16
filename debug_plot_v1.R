# DEBUG THIS

plot_data <- feats_df %>%
  group_by(method, dataset) %>%
  arrange(desc(abs(coef)), .by_group = TRUE) %>%
  group_map(~ {
    # Find a match in the reference df to see its corresponding counts
    matched <- all_counts_df %>%
      filter(method == .y$method, dataset == .y$dataset)

    # Get the number of true and noise this depends on the all_counts_df
    top_num <- matched %>% pull( true_count )
    bottom_num <- matched %>% pull( noise_count )

    # Then pull each
    top_sliced <- slice_head(.x , n = top_num) %>%
      count(feature_type, name = "n_selected") %>%
      mutate(category = "top_truth")
    bottom_sliced <- slice_head(.x, n = bottom_num) %>%
      count(feature_type, name = "n_selected") %>%
      mutate(category = "bottom_noise")

    binded <- bind_rows(top_sliced, bottom_sliced)
    output <- bind_cols(.y, binded)
    return(output)
  }) %>%
  bind_rows() %>%
  ungroup() %>%
  rename(n = n_selected) %>%
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
