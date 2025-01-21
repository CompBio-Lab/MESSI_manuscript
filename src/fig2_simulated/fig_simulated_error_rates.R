# Load libraries
library(tidyverse)
library(here)
# First load data
data_path <- here("data/metrics-sim_data_with_rep.csv")


wrangle_data <- function(df) {
  clean_df <- df %>%
    rename(method = method_name) %>%
    # Given there's same result for rgcca and sgcca
    # going to drop those of rgcca and retain sgcca only.
    filter(method != "rgcca") %>%
    # Add identifier to tell which one real or simulated
    group_by(method, dataset) %>%
    summarise(
      across(
        .cols=c(auc, f1_score, accuracy, balanced_accuracy, precision, recall),
        .fns=list(mean = mean, sd = sd)),
      .groups = "drop"
    ) %>%
    ungroup() %>%
    # Then rank the performance of each method within each dataset
    # I.e. For Dataset L, could be m1, m3 , m5, m2 , m6 from best to worst (left to right)
    group_by(dataset) %>%
    # TODO:  ~~Sort in desceding order, and rank them, i.e. 1st equals top performing~~
    #mutate(ranking = rank(desc(auc_mean))) %>%
    mutate(ranking = rank(auc_mean)) %>%
    ungroup() %>%
    mutate(
      is_simulated = case_when(
        str_detect(dataset, "sim") ~ "yes",
        TRUE ~ "no"
      )
    ) %>%
    # Rename method names
    mutate(
      method = case_when(
        str_detect(method, "mofa") ~ "mofa + glmnet",
        str_detect(method, "sgcca") ~ "sgcca + lda",
        TRUE ~ method
      )
    ) %>%
    select(
      method, dataset, ranking,
      auc_mean, auc_sd, f1_score_mean, f1_score_sd, is_simulated
    ) %>%
    arrange(ranking)
  return(clean_df)
}



# ======================================
# More helper


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
}

# ======================================

# rho is correlation
# dt is signal
clean_df <- read.csv(data_path) %>%
  as_tibble() %>%
  wrangle_data() %>%
  select(-c(is_simulated)) %>%
  retrieve_sim_params() %>%
  mutate(strategy = case_when(
    strategy == "pced" ~ "messi_sim",
    TRUE ~ "intersim"
  )) %>%
  rename(corr = rho,
         signal = dt)



# TODO: FIX dts to show diagonal (linear positive) pattern
err_rate_box_plot <- clean_df  %>%
  ggplot(aes(x = method, y = auc_mean, fill=factor(signal))) +
  geom_boxplot() +
  theme_bw() +
  facet_grid(strategy ~ corr, label = label_both, scales="free") +
  theme(axis.text.x = element_text(angle = 45, hjust=1)) +
  labs(title = "AUC Scores plot", fill = "Signal")

err_rate_box_plot


# library(ggridges)
#
# ridge_plot <- clean_df %>%
# ggplot(aes(x = auc_mean, y = method, fill = factor(dt))) +
#   geom_density_ridges(alpha = 0.6) +
#   labs(title = "Ridgeline Plot of AUC Scores", x = "AUC Score", y = "Method") +
#   theme_ridges() +
#   facet_grid(~strategy) +
#   theme(legend.position = "top")
#
#
#
# ridge_plot
