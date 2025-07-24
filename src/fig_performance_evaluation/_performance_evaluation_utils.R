suppressPackageStartupMessages(library(dplyr))
library(tibble)
library(here)
library(stringr)
library(tidyr)


wrangle_data <- function(df) {
  wrangle_df <- df %>%
    rename(method = method_name) %>%
    # Given there's same result for rgcca and sgcca
    # going to drop those of rgcca and retain sgcca only.
    #filter(!str_detect(method, "sgcca")) %>%
    # Remove the first component results from diablo
    #filter(!str_detect(method, "diablo.*ncomp-1")) %>%
    group_by(method, dataset) %>%
    #summarise(
    #  across(
    #    .cols=c(auc, f1_score),
    #    .fns=list(mean = mean, sd = sd)),
    #  .groups = "drop"
    #) %>%
    #ungroup() %>%
    # Then rank the performance of each method within each dataset
    # I.e. For Dataset L, could be m1, m3 , m5, m2 , m6 from best to worst (left to right)
    group_by(dataset) %>%
    # TODO:  ~~Sort in desceding order, and rank them, i.e. 1st equals top performing~~
    #mutate(ranking = rank(desc(auc_mean))) %>%
    mutate(ranking = rank(auc)) %>%
    ungroup() %>%
    # Rename method names
    mutate(
      method = case_when(
        str_detect(method, "mofa") ~ "mofa + glmnet",
        str_detect(method, "rgcca") ~ paste0(method, " + lda"),
        str_detect(method, "cooperative") ~ "multiview",
        TRUE ~ method
        )
    ) %>%
    select(
      method, dataset, ranking,
      auc, f1_score
    ) %>%
    arrange(ranking)
  return(wrangle_df)
}
