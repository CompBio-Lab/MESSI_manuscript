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
get_top_bottom_counts_df <- function(feats_df, total_feat_counts_df) {
  counts_df <- feats_df %>%
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
    {.}


  return(counts_df)
}

# Also get the metadata like simulation parameters of each dataset
sim_data_params_df <- feats_df %>%
  filter(str_detect(dataset, "sim")) %>%
  mutate(
    strategy = str_extract(dataset, "(?<=_strategy-)[^_]+"),
    n = as.numeric(str_extract(dataset, "(?<=_n-)[0-9]+")),
    H = as.numeric(str_extract(dataset, "(?<=_H-)[0-9]+")),
    effect = as.numeric(str_extract(dataset, "(?<=_effect-)[0-9.]+")),
    e = as.numeric(str_extract(dataset, "(?<=_e-)[0-9]+")),
    corr = as.numeric(str_extract(dataset, "(?<=_corr-)[0-9.]+"))
  ) %>% # Now only look at those on intersim
  filter(strategy == "intersim") %>%
  select(dataset, strategy, n, H, effect, e, corr) %>%
  distinct()


top_bottom_counts_df <- get_top_bottom_counts_df(feats_df, total_feat_counts_df)

top_bottom_counts_df

feat_selection_metrics_df <- top_bottom_counts_df %>%
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
    N = sum(TP, TN, FP, FN),
    .groups = "drop"
  ) %>%
  group_by(dataset, view, method) %>%
  summarize(
    accuracy = (TP + TN)/N,
    recall = TP / (TP + FN),
    specificity = TN / (TN + FP),
    precision = TP / (TP + FP),
    f1_score = 2 * precision * recall / (precision + recall)
  ) %>%
  ungroup()


feat_selection_metrics_df

# Then for plotting
plot_df <- feat_selection_metrics_df %>%
  left_join(sim_data_params_df, by="dataset")

plot_df %>%
  pivot_longer(cols = accuracy:f1_score,  # Specify metric columns
               names_to = "metric",                  # Name for the new column
               values_to = "value") %>%
  ggplot(
    aes(
      x = factor(corr), y = value,
      color = metric, linetype = view, group = interaction(metric, view)
      )
  ) +
  geom_line(size = 1) +
  geom_point() +
  #geom_ribbon(aes(ymin = accuracy - sd_accuracy, ymax = accuracy + sd_accuracy, fill = view), alpha = 0.2) +
  facet_wrap(~effect) +  # Facet by `effect`
  labs(title = "Accuracy vs Correlation for Different Views",
       x = "Correlation (corr)",
       y = "Accuracy",
       color = "View",
       fill = "View") +
  theme_bw()



# VERY BAD PLOT???
effects <- sim_data_params_df$effect |> unique()
effect_labels <- paste0("Effect = ", effects)
names(effect_labels) <- effects


plot_df %>%
  #pivot_longer(cols = accuracy:f1_score,  # Specify metric columns
  #             names_to = "metric",                  # Name for the new column
  #             values_to = "value") %>%
  ggplot(
    aes(
      x = method, y = accuracy, fill = method
    )
  ) +
  stat_boxplot(geom ='errorbar') +
  geom_boxplot() +
  facet_wrap(
    ~effect, scales="free",
    labeller = labeller(effect = effect_labels)
    ) +  # Facet by `effect`
  scale_fill_brewer(palette = "Paired") +
  theme_bw() +
  theme(axis.text.x = element_text(angle = 45, hjust=1))


# Doesnt make sense here
plot_df  %>%
  ggplot(aes(x=method, y = accuracy, color = view)) +
  geom_point(size=2)  +
  facet_wrap(
    ~effect, scales="free",
    labeller = labeller(effect = effect_labels)
  ) +
  theme(axis.text.x = element_text(angle = 45, hjust=1))


# =======================================

library(pheatmap)

plot_mat <- feat_selection_metrics_df %>%
  group_by(method, dataset) %>%
  summarise(mean_accuracy = mean(accuracy)) %>%
  pivot_wider(
    names_from = c(dataset),
    values_from = mean_accuracy,
    values_fill = NA
  ) %>%
  column_to_rownames("method") %>%
  as.matrix()


col_metadata <- data.frame(
  views = str_extract(colnames(plot_mat), "_(expr|methyl|protein)$") %>%
  str_remove("^_"),
  effect = str_extract(colnames(plot_mat), "(?<=effect-)[^_]+"),
  corr = str_extract(colnames(plot_mat), "(?<=corr-)[^_]+"),
  n = str_extract(colnames(plot_mat), "(?<=n-)[^_]+")
  ) %>%
  mutate(
    effect = case_when(
      effect == 0 ~ "low",
      effect == 0.5 ~ "med",
      TRUE ~ "high"
    ),
    corr = case_when(
      corr == 0 ~ "low",
      corr == 0.5 ~ "med",
      TRUE ~ "high"
    ),
    n = case_when(
      n == 50 ~ "low",
      n == 100 ~ "med",
      TRUE ~ "high"
    )
  ) %>%
  select(-views)

rownames(col_metadata) <- colnames(plot_mat)


# Set row names of annotation to match column names of plot_mat
#rownames(col_metadata) <- colnames(plot_mat)

ann_colors <- list(
  corr = c("high" = "#F46D43",
                     "med" = "#708238",
                     "low" = "beige"),
  effect = c("high" = "violet",
           "med" = "pink",
           "low" = "beige"),
  n = c("high" = "blueviolet",
        "med" = "darkgreen",
        "low" = "beige")
)

pheatmap(plot_mat, show_colnames = F,
         annotation_col = col_metadata,
         annotation_colors = ann_colors,
         cluster_cols = T)
