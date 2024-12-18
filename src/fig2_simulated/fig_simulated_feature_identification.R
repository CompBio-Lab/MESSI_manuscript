# This one identifies feature selection results from simulation

data_path <- "data/sim_data_fs_results/merge_selected_features/all_feature_selection_results.csv"


library(tidyverse)
library(hrbrthemes)

source(here::here("src/fig2_simulated/helpers.R"))

# Custom functions

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
  # From n_total to p_total
  mutate(p_total = noise_count + true_count)


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


# ======================================================
# See for diablo now?
methods <- c("diablo-full")
feats_df %>%
  filter(method %in% methods) %>%






# =============================================================================
plot_data %>%
  sample_n(2)

palette <- "Paired"

p1 <- plot_data %>%
  ggplot(aes(x = method, y = sensitivity, fill=method)) +
  geom_boxplot() +
  theme_bw() +
  labs(title="Sensitivity of feature selection results",
       fill="Method") +
  scale_fill_brewer(palette=palette)


p2 <- plot_data %>%
  ggplot(aes(x = method, y = sensitivity, fill=factor(dt))) +
  geom_boxplot() +
  theme_bw() +
  labs(title="Sensitivity of feature selection results aggregated by dt",
       color="dt") +
  scale_fill_brewer(palette="Pastel2")


p3 <- plot_data %>%
  #filter(dt >= 20) %>%
  group_by(method, dt) %>%
  summarize(avg_sensitivity = mean(sensitivity)) %>%
  ggplot(aes(x=method, y=avg_sensitivity, group=factor(dt), color=factor(dt))) +
  geom_point() +
  geom_line() +
  theme_bw() +
  scale_color_brewer(palette="Dark2") +
  labs(color = "dt", title="Average Sensitivity (by rho) aggregated by dt")

p1

p2

p3

plot_data %>%
  filter(method == "diablo-null")


plot_data %>%
  ggplot(aes(x = method, y = sensitivity)) +
  geom_point() +
  theme_bw() +
  facet_grid(rho ~ dt, label = label_both) +
  labs(title="Sensitivity of feature selection results aggregated by dt",
       color="dt") +
  scale_fill_brewer(palette="Pastel2")





