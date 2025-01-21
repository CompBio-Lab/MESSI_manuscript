# This one identifies feature selection results from simulation

#data_path <- "data/sim_data_fs_results/merge_selected_features/all_feature_selection_results.csv"
#data_path <- "data/diablo-fs_results.csv"

data_path <- "data/sim_data_fs_results_with_reps.csv"

library(tidyverse)
#library(hrbrthemes)

#source(here::here("src/fig2_simulated/helpers.R"))

# Custom functions

get_fs_stats <- function(top_bottom_counts,
                         top_identifier="top_counts",
                         bottom_identifier="bottom_counts") {
  top_bottom_counts %>%
    group_by(method, dataset, view) %>%
    summarise(
      TP = sum(n[category == top_identifier & feature_type == "true"], na.rm = TRUE),
      FP = sum(n[category == top_identifier & feature_type == "noise"], na.rm = TRUE),
      FN = sum(n[category == bottom_identifier & feature_type == "true"], na.rm = TRUE),
      TN = sum(n[category == bottom_identifier & feature_type == "noise"], na.rm = TRUE),
      N = sum(TP, TN, FP, FN),
      .groups = "drop"
    )
}


# Load data
feats_df <- read.csv(data_path) %>%
  as_tibble() %>%
  rename(dataset = dataset_name) %>%
  mutate(feature_type = case_when(
    #str_detect(feature, "true") ~ "true",
    str_detect(feature, "noise") ~ "noise",
    TRUE ~ "true"
  ))


# Separate to get all counts
all_counts_df <- feats_df %>%
  group_by(method, dataset, view, feature_type) %>%
  summarize(n = n()) %>%
  ungroup() %>%
  pivot_wider(names_from = "feature_type", values_from = "n") %>%
  rename(noise_count = noise,
         true_count = true) %>%
  # From n_total to p_total
  mutate(p_total = noise_count + true_count)



# Then this gets to some summary stats of binary classification
wrangled_data <- feats_df %>%
  group_by(method, dataset, view) %>%
  arrange(desc(abs(coef)), .by_group = TRUE) %>%
  group_map(~ {
    # Find a match in the reference df to see its corresponding counts
    matched <- all_counts_df %>%
      filter(method == .y$method, dataset == .y$dataset, view == .y$view)

    # Get the number of true and noise this depends on the all_counts_df
    top_num <- matched %>% pull( true_count )
    bottom_num <- matched %>% pull( noise_count )

    # Then pull each
    top_sliced <- slice_head(.x , n = top_num) %>%
      count(feature_type, name = "n_selected") %>%
      mutate(category = "top_truth")
    bottom_sliced <- slice_tail(.x, n = bottom_num) %>%
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
  group_by(method, dataset, view) %>%
  summarize(
    sensitivity = TP / (TP + FN),
    specificity = TN / (TN + FP),
    precision = TP / (TP + FP),
    accuracy = (TP + TN) / N
    )  %>%
  ungroup()



retrieve_sim_params <- function(df) {
  df %>%
    # First handle the strategy, then handle params separately based on strategy
    mutate(
      # Extract the strategy part
      strategy = str_extract(dataset, "strategy-[^_]+") %>%
        str_remove("strategy-"),
      # Extract the rest of the parameters
      params = str_extract(dataset, "strategy-[^_]+_(.*)$") %>%
        str_remove("^strategy-[^_]+_")
    )  %>%
    mutate(
      n = str_extract(params, "n-\\d+"),
      dt = str_extract(params, "dt-\\d+"),
      rho = str_extract(params, "rho-[\\d\\.]+"),
      rep = str_extract(params, "rep-\\d+")
    ) %>%
    mutate(across(n:rep, ~ str_remove(., "^[a-z]+-") %>% as.numeric())) %>%
    select(-c(params))
    # # Separate columns based on strategy
    # tidyr::separate(messi_params, into = c("n", "p", "j", "dt", "rho", "rep"), sep = "_") %>%
    # tidyr::separate(intersim_params, into = c("n", "dt", "rho", "rep"), sep = "_") %>%

    # dplyr::mutate(
    #   dplyr::across(n:rep, ~ stringr::str_extract(., "[0-9.]+") %>% as.numeric())
    # )
}



# ======================================================
# See for diablo now?
#methods <- c("diablo-full")
#feats_df %>%
#  filter(method %in% methods) %>%

# plot_data %>%
#   ggplot(aes(x=method, y=sensitivity, fill=view)) +
#   geom_boxplot() +
#   theme_bw() +
#   facet_grid(dt~rho, labeller = label_both)


# plot_data$strategy |> unique()
# plot_data %>%
#   filter(strategy == "intersim")


# =============================================================================
#plot_data %>%
#  sample_n(2)

plot_data <- wrangled_data %>%
  retrieve_sim_params() %>%
# Let expr and omic 1 being same view, methyl and omic2 being same, and protein
# with omic3 being same
  mutate(
    new_view = case_when(
      view == "expr" | view == "omic1" ~ "g1",
      view == "methyl" | view == "omic2" ~ "g2",
      view == "protein" | view == "omic3" ~ "g3",
      TRUE ~ NA
    ),
    strategy = case_when(
      strategy == "pced" ~ "messi_sim",
      TRUE ~ strategy
    )
  ) %>%
  rename(corr = rho,
         signal = dt)

# ===============================================================
# PLOT STUFF
# QUITE CONTRADICTING
palette <- "Paired"

p1 <- plot_data %>%
  # UNCOMMENT THIS
  #filter(strategy == "messi_sim") %>%
  filter(method != "rgcca") %>%
  ggplot(aes(x = method, y = sensitivity, fill=factor(signal))) +
  geom_boxplot() +
  theme_bw() +
  # TODO: fix y-lims
  facet_grid(strategy ~ corr, label = label_both, scales="free") +
  ylim(breaks=c(0,1)) +
  theme(axis.text.x = element_text(angle = 45, hjust=1)) +
  labs(title = "Feature Identification Sensitivity", fill = "signal")



p1 +
  scale_y_continuous(breaks=seq(0, 1, by = 0.1))



#ggsave(filename="results/dt_vs_strategy_fs_sensitivity_boxplot.png", plot=p1)



# p1 <- plot_data %>%
#   ggplot(aes(x = method, y = sensitivity, fill=method)) +
#   geom_boxplot() +
#   theme_bw() +
#   labs(title="Sensitivity of feature selection results",
#        fill="Method") +
#   scale_fill_brewer(palette=palette)
#
# p1
# p2 <- plot_data %>%
#   ggplot(aes(x = method, y = sensitivity, fill=factor(dt))) +
#   geom_boxplot() +
#   theme_bw() +
#   labs(title="Sensitivity of feature selection results aggregated by dt",
#        color="dt") +
#   scale_fill_brewer(palette="Pastel2")
#
#
# p3 <- plot_data %>%
#   #filter(dt >= 20) %>%
#   group_by(method, dt) %>%
#   summarize(avg_sensitivity = mean(sensitivity)) %>%
#   ggplot(aes(x=method, y=avg_sensitivity, group=factor(dt), color=factor(dt))) +
#   geom_point() +
#   geom_line() +
#   theme_bw() +
#   scale_color_brewer(palette="Dark2") +
#   labs(color = "dt", title="Average Sensitivity (by rho) aggregated by dt")
#
# p1
#
# p2
#
# p3
#
# plot_data %>%
#   filter(method == "diablo-null")
#
#
# new_p_data %>%
#   ggplot(aes(x = method, y = sensitivity, color=method)) +
#   geom_point() +
#   theme_bw() +
#   facet_grid(rho ~ dt, label = label_both) +
#   labs(title="Sensitivity of feature selection results aggregated by dt",
#        color="dt") +
#   scale_fill_brewer(palette="Pastel2")
#
#
# p
#
#




