get_top_bottom_counts_df <- function(feats_df, total_feat_counts_df, true_label, noise_label) {
  counts_df <- feats_df %>%
    group_by(method, dataset) %>%
    arrange(desc(abs(coef)), .by_group = TRUE) %>%
    group_map(~ {
      # Find a match in the reference df to see its corresponding counts
      matched <- total_feat_counts_df %>%
        filter(method == .y$method, dataset == .y$dataset)

      # Get the number of true and noise
      true_num <- matched %>% pull( {{ true_label }} )
      noise_num <- matched %>% pull( {{ noise_label }} )

      if (is.na(true_num)) {
        message("Dataset: ", .y$dataset, " Method: ", .y$method, " has NA in feature count")
        true_num <- 0
      }

      if (is.na(noise_num)) {
        message("Dataset: ", .y$dataset, " Method: ", .y$method, " has NA in feature count")
        noise_num <- 0
      }
      # Then pull each
      top_sliced <- slice_head(.x , n = true_num) %>%
        count(feature_type, name = "n_selected") %>%
        mutate(category = "top_count")
      bottom_sliced <- slice_head(.x, n = noise_num) %>%
        count(feature_type, name = "n_selected") %>%
        mutate(category = "bottom_count")

      binded <- bind_rows(top_sliced, bottom_sliced)
      output <- bind_cols(.y, binded)
      return(output)
    }) %>%
    bind_rows() %>%
    ungroup()

  return(counts_df)
}

library(testthat)

# Load test data
test_data <- read.csv("data/feature_selection_test_data.csv") %>% as_tibble()

total_feats_df <- test_data %>%
  group_by(method, dataset, feature_type) %>%
  summarize(n = n()) %>%
  ungroup() %>%
  pivot_wider(names_from = "feature_type", values_from = "n") %>%
  rename(noise_count = noise,
         true_count = true) %>%
  # From n_total to p_total
  mutate(p_total = noise_count + true_count)

top_count <- get_top_bottom_counts_df(test_data, total_feats_df,
                                      true_label=true_count,
                                      noise_label=noise_count)

test_that("Should work", {
  expect_equal()
})

