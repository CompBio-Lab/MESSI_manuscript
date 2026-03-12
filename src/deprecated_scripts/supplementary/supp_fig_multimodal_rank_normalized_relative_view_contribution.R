standardize_method_names <- function(df) {
  df %>%
  mutate(
    method = case_when(
      str_detect(method, "cooperative_learning") ~ "multiview",
      str_detect(method, "mofa") ~ paste(method, "glmnet", sep = " + " ),
      str_detect(method, "gcca") ~ paste(method, "lda", sep = " + "),
      TRUE ~ method
    )
  )
}
standardize_view_names <- function(df) {
  df %>%
  dplyr::mutate(
    method = case_when(
      str_detect(view, "ncomp") ~ paste(method, str_extract(view, "ncomp-\\d+"), sep = "-"),
      str_detect(view, "Factor") ~ paste(method, str_extract(view, "Factor\\d+"), sep = "-"),
      TRUE ~ method
    ),
    view_cleaned = case_when(
      str_detect(view, "ncomp") ~ str_remove(view, "-ncomp.*"),
      str_detect(view, "Factor") ~ str_remove(view, "-Factor.*"),
      TRUE ~ view
    ),
    feat = str_remove(feature, paste0("^", view_cleaned, "_")),
    view = view_cleaned
  ) %>%
    dplyr::select(-view_cleaned)
}

#metadata <- read.csv("data/raw/multimodal_data/parsed_metadata.csv")
#metadata
df <- data.table::fread("data/raw/multimodal_data/all_feature_selection_results.csv") |>
  dplyr::select(-feature_type, -dataset_type) %>%
  # First step always standardize view and method name
  standardize_view_names() %>%
  standardize_method_names()


# option_a <- df[, .(
#   mean_abs_coef  = mean(abs(coef)),
#   sum_abs_coef   = sum(abs(coef)),
#   median_abs_coef = median(abs(coef)),
#   n_features     = .N,
#   n_nonzero      = sum(coef != 0)
# ), by = .(method, dataset_name, view)]
#
#
#
# # Normalize so each method+dataset sums to 1 (relative view contribution)
# option_a[, rel_contribution := sum_abs_coef / sum(sum_abs_coef),
#          by = .(method, dataset_name)]



option_a <- df %>%
  group_by(method, dataset_name, view) %>%
  summarise(
    mean_abs_coef   = mean(abs(coef)),
    sum_abs_coef    = sum(abs(coef)),
    median_abs_coef = median(abs(coef)),
    n_features      = n(),
    n_nonzero       = sum(coef != 0),
    .groups = "drop"
  ) %>%
  group_by(method, dataset_name) %>%
  mutate(
    total_abs_coef = sum(sum_abs_coef),
    rel_contribution = sum_abs_coef / total_abs_coef
  ) %>%
  dplyr::select(-total_abs_coef) %>%
  ungroup()


p_a <-
  option_a %>%
  filter(!str_detect())
  ggplot(option_a, aes(x = view, y = method, fill = rel_contribution)) +
  geom_tile(color = "white") +
  facet_wrap(~ dataset_name, scales = "free_x") +
  #scale_fill_gradient(low = "white", high = "#2c7bb6", name = "Relative\nContribution") +

  # Option 3: viridis — perceptually uniform and naturally saturated
  scale_fill_viridis_c(option = "plasma", name = "Relative\nContribution") +
  labs(title = "Multimodal Relative View contribution",
       x = "View", y = "Method") +
  theme_cowplot(12) +
  theme(axis.text.x = element_text(angle = 45, hjust = 1))



  # Rank-normalize: rank sum_abs_coef within each method+dataset, then normalize
  # This removes scale differences across methods so cross-method comparison is valid

  option_a_raw <- option_a


  option_a <- option_a_raw |> as.data.table()
  option_a[, rank_sum_abs_coef := rank(sum_abs_coef, ties.method = "average"),
           by = .(method, dataset_name)]

  option_a[, rel_contribution_ranked := rank_sum_abs_coef / sum(rank_sum_abs_coef),
           by = .(method, dataset_name)]


  p_a_ranked <- ggplot(option_a, aes(x = view, y = method, fill = rel_contribution_ranked)) +
    geom_tile(color = "white") +
    facet_wrap(~ dataset_name, scales = "free_x") +
    scale_fill_viridis_c(option = "plasma", name = "Rank-normalized\nContribution") +
    labs(title = "Option A (rank-normalized): Cross-method view contribution",
         subtitle = "Rank of sum(|coef|) per view, normalized within method+dataset",
         x = "View", y = "Method") +
    theme_cowplot(12) +
    theme(axis.text.x = element_text(angle = 45, hjust = 1))

  p_a_ranked
