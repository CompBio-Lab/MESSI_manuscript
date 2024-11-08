# Load libs
library(tidyverse)
library(stringr)
library(tidyr)
library(here)
theme_set(theme_bw())

feats_path <- here("data", "all_feature_selection_results.csv")

# Read the data in and only retain the features from those simulated datasets
feats_df <- read.csv(feats_path) |>
  as_tibble() %>%
  # And rename column
  rename(dataset = dataset_name) %>%
  filter(str_detect(dataset, "sim")) %>%
  # And also looking at those of intersim only now
  filter(str_detect(dataset, "intersim")) %>%
  # Create extra column for knowing if the feat is meaningful or noise
  mutate(
    feature_type = case_when(
      str_detect(feature, "noise") ~ "noise",
      TRUE ~ "truth"
    )
  )


# # So say looking at one data only
# dname <- feats_df$dataset %>% unique() %>% head(1)
# dnames <- feats_df$dataset %>% unique() %>% head(2)


#=========================================
total_feat_counts_df <- feats_df %>%
  #filter(str_detect(method, "mofa|mogonet"),
  #       dataset %in% dnames) %>%
  group_by(method, dataset, view, feature_type) %>%
  summarize(n_total = n()) %>%
  ungroup()


# =========================================================
# This would group by method, dataset, view level
get_conf_mat_df <- function(feats_df, total_feat_counts_df) {
  conf_mat_df <- feats_df %>%
  # filter(str_detect(method, "mofa|mogonet"),
  #        dataset %in% dnames) %>%
  group_by(method, dataset, view) %>%
  arrange(desc(abs(coef)), .by_group = T) %>%
  group_map(~ {
    # .x are the data without the grouping keys
    # .y are the grouping keys method, dataset
    matched <- total_feat_counts_df %>%
      filter(method == .y$method,
             dataset == .y$dataset,
             view == .y$view)
    #print(matched)
    # Then get the number of truth feat
    top_num <- matched %>%
             filter(feature_type == "truth") %>%
              pull(n_total)
    # Then get the number of noise feat
    bottom_num <- matched %>%
      filter(feature_type == "noise") %>%
      pull(n_total)


    #print(paste0("This is top num: ", top_num, " This is bottom num: ", bottom_num))
    # Then applying slicing for both
    top_sliced <- slice_head(.x, n = top_num) %>%
      count(feature_type, name = "n_selected") %>%
      mutate(category = "top_truth", top_num = top_num)

    bottom_sliced <- slice_tail(.x, n = bottom_num) %>%
      count(feature_type, name = "n_selected") %>%
      mutate(category = "bottom_noise", bottom_num = bottom_num)

    # Combine results for this group
    binded <- bind_rows(top_sliced, bottom_sliced)
    # And prepend group keys in front
    output <- bind_cols(.y, binded)
    return(output)
  }) %>%
  bind_rows() %>%
  ungroup() %>%
  group_by(dataset, view, method) %>%
  # TP: Features correctly identified as truth (top_truth with feature_type == truth).
  # FP: Features incorrectly identified as truth (top_truth with feature_type == noise).
  # FN: Features incorrectly identified as noise (bottom_noise with feature_type == truth).
  # TN: Features correctly identified as noise (bottom_noise with feature_type == noise).
  summarise(
    TP = sum(n_selected[category == "top_truth" & feature_type == "truth"], na.rm = TRUE),
    FP = sum(n_selected[category == "top_truth" & feature_type == "noise"], na.rm = TRUE),
    FN = sum(n_selected[category == "bottom_noise" & feature_type == "truth"], na.rm = TRUE),
    TN = sum(n_selected[category == "bottom_noise" & feature_type == "noise"], na.rm = TRUE),
    .groups = "drop"
  )

  return(conf_mat_df)
}




conf_mat_df <- get_conf_mat_df(feats_df, total_feat_counts_df)

conf_mat_df

