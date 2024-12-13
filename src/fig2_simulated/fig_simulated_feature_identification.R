# This one identifies feature selection results from simulation

data_path <- "data/sim_data_fs_results/merge_selected_features/all_feature_selection_results.csv"


library(tidyverse)

# Custom functions
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

get_fs_stats <- function(top_bottom_counts,
                         top_identifier="top_counts",
                         bottom_identifier="bottom_counts") {
  top_bottom_counts %>%
    group_by(method, dataset) %>%
    summarise(
      TP = sum(n[category == top_identifier & feature_type == "true"], na.rm = TRUE),
      FP = sum(n[category == top_identifier & feature_type == "noise"], na.rm = TRUE),
      FN = sum(n[category == bottom_identifier & feature_type == "true"], na.rm = TRUE),
      TN = sum(n[category == bottom_identifier & feature_type == "noise"], na.rm = TRUE),
      N = sum(TP, TN, FP, FN),
      .groups = "drop"
    )
}


retrieve_sim_params <- function(df) {
  df %>%
    tidyr::separate(
      dataset,
      into = c("type", "strategy", "n", "p", "j", "dt", "rho"),
      sep = "_") %>%
    dplyr::mutate(
      dplyr::across(n:rho, ~ stringr::str_extract(., "[0-9.]+") %>% as.numeric())
    ) %>%
    dplyr::select(-type)

}





# Load data
feats_df <- read.csv(data_path) %>%
  as_tibble() %>%
  rename(dataset = dataset_name) %>%
  mutate(feature_type = case_when(
    str_detect(feature, "true") ~ "true",
    str_detect(feature, "noise") ~ "noise",
    TRUE ~ NA
  ))

# dname <- feats_df$dataset %>% unique() %>% sample(1)
# feats_df %>%
#   filter(dataset == dname) %>%
#   filter(method == "mogonet")
#   #group_by(method) %>%
#   #summarize(n=n())


all_counts_df <- feats_df %>%
  group_by(method, dataset, feature_type) %>%
  summarize(n = n()) %>%
  ungroup() %>%
  pivot_wider(names_from = "feature_type", values_from = "n") %>%
  rename(noise_count = noise,
         true_count = true) %>%
  mutate(n_total = noise_count + true_count)


# Then this gets to some summary stats of binary classification
plot_data <- feats_df %>%
  get_top_bottom_counts_df(all_counts_df, true_label = true_count, noise_label = noise_count) %>%
  rename(n = n_selected) %>%
  get_fs_stats(top_identifier = "top_count", bottom_identifier = "bottom_count") %>%
  group_by(method, dataset) %>%
  summarize(
    sensitivity = TP / (TP + FN),
    specificity = TN / (TN + FP),
    precision = TP / (TP + FP),
    accuracy = (TP + TN) / N
    )  %>%
  ungroup() %>%
  retrieve_sim_params()


# =============================================================================
# Then for plotting goes here
plot_data %>%
  arrange(sensitivity)






plot_data %>%
  ggplot(aes(x = method, y = sensitivity, fill=factor(dt))) +
  geom_boxplot() +
  theme_bw()


